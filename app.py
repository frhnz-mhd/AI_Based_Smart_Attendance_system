import os
import csv
import sqlite3
import datetime
from functools import wraps

import cv2
import numpy as np
from PIL import Image

from flask import (
    Flask, render_template, request, redirect,
    url_for, session, jsonify, send_file
)
from werkzeug.security import generate_password_hash, check_password_hash


APP_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(APP_DIR, "attendance.db")

UPLOAD_DIR = os.path.join(APP_DIR, "static", "captures")
DATASET_DIR = os.path.join(APP_DIR, "dataset")
TRAINER_DIR = os.path.join(APP_DIR, "trainer")
MODEL_PATH = os.path.join(TRAINER_DIR, "trainer.yml")

CASCADE_PATH = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(DATASET_DIR, exist_ok=True)
os.makedirs(TRAINER_DIR, exist_ok=True)

app = Flask(__name__)
app.secret_key = "change-this-secret-key"

face_cascade = cv2.CascadeClassifier(CASCADE_PATH)


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def add_column_if_missing(cursor, table, column, col_type):
    try:
        cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}")
    except sqlite3.OperationalError:
        pass


def init_db():
    conn = get_db()
    c = conn.cursor()

    c.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL,
            reg_no TEXT
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reg_no TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            course TEXT,
            class_name TEXT,
            phone TEXT
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reg_no TEXT NOT NULL,
            name TEXT NOT NULL,
            date TEXT NOT NULL,
            time TEXT NOT NULL,
            status TEXT NOT NULL,
            liveness TEXT,
            attention TEXT,
            confidence REAL,
            image_path TEXT,
            latitude TEXT,
            longitude TEXT
        )
    """)

    add_column_if_missing(c, "attendance", "latitude", "TEXT")
    add_column_if_missing(c, "attendance", "longitude", "TEXT")

    admin = c.execute("SELECT * FROM users WHERE username='admin'").fetchone()

    if not admin:
        c.execute(
            "INSERT INTO users(username,password,role,reg_no) VALUES(?,?,?,?)",
            ("admin", generate_password_hash("admin123"), "admin", None)
        )

    demo_student = c.execute(
        "SELECT * FROM students WHERE reg_no='20230123'"
    ).fetchone()

    if not demo_student:
        c.execute(
            "INSERT INTO students(reg_no,name,course,class_name,phone) VALUES(?,?,?,?,?)",
            ("20230123", "John Doe", "BSCS", "4A", "+94 700000000")
        )

        c.execute(
            "INSERT INTO users(username,password,role,reg_no) VALUES(?,?,?,?)",
            ("20230123", generate_password_hash("student123"), "student", "20230123")
        )

    conn.commit()
    conn.close()


def now_sl():
    return datetime.datetime.utcnow() + datetime.timedelta(hours=5, minutes=30)


def login_required(role=None):
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            if "user_id" not in session:
                return redirect(url_for("login"))

            if role and session.get("role") != role:
                return redirect(url_for("login"))

            return fn(*args, **kwargs)

        return wrapper

    return decorator


def student_name(reg_no):
    conn = get_db()
    s = conn.execute(
        "SELECT name FROM students WHERE reg_no=?",
        (reg_no,)
    ).fetchone()
    conn.close()

    return s["name"] if s else "Unknown Student"


def decode_image_from_request(file_storage):
    file_bytes = np.frombuffer(file_storage.read(), np.uint8)
    return cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)


def detect_largest_face(gray):
    faces = face_cascade.detectMultiScale(
        gray,
        scaleFactor=1.1,
        minNeighbors=3,
        minSize=(50, 50)
    )

    if len(faces) == 0:
        return None

    return max(faces, key=lambda box: box[2] * box[3])


def create_recognizer():
    if not hasattr(cv2, "face"):
        raise RuntimeError(
            "Install opencv-contrib-python using: pip install opencv-contrib-python"
        )

    return cv2.face.LBPHFaceRecognizer_create()


def prepare_training_face_from_path(img_path):
    frame = cv2.imread(img_path)

    if frame is None:
        return None

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (320, 240))

    face = detect_largest_face(gray)

    if face is not None:
        x, y, w, h = face
        face_img = gray[y:y + h, x:x + w]
        face_img = cv2.resize(face_img, (200, 200))
        return face_img

    return cv2.resize(gray, (200, 200))


@app.route("/")
def index():
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    error = None

    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()

        conn = get_db()
        user = conn.execute(
            "SELECT * FROM users WHERE username=?",
            (username,)
        ).fetchone()
        conn.close()

        if user and check_password_hash(user["password"], password):
            session["user_id"] = user["id"]
            session["username"] = user["username"]
            session["role"] = user["role"]
            session["reg_no"] = user["reg_no"]

            if user["role"] == "admin":
                return redirect(url_for("admin_dashboard"))

            return redirect(url_for("student_home"))

        error = "Invalid username or password"

    return render_template("login.html", error=error)


@app.route("/api/login", methods=["POST"])
def api_login():
    data = request.get_json(silent=True) or {}

    username = data.get("username", "").strip()
    password = data.get("password", "").strip()

    if not username or not password:
        return jsonify({
            "success": False,
            "message": "Username and password are required."
        }), 400

    conn = get_db()

    user = conn.execute(
        "SELECT * FROM users WHERE username=?",
        (username,)
    ).fetchone()

    if not user:
        conn.close()
        return jsonify({
            "success": False,
            "message": "User not found."
        }), 401

    if not check_password_hash(user["password"], password):
        conn.close()
        return jsonify({
            "success": False,
            "message": "Wrong password."
        }), 401

    student = None

    if user["role"] == "student":
        student = conn.execute(
            "SELECT * FROM students WHERE reg_no=?",
            (user["reg_no"],)
        ).fetchone()

    conn.close()

    return jsonify({
        "success": True,
        "message": "Login successful.",
        "role": user["role"],
        "reg_no": user["reg_no"],
        "name": student["name"] if student else "Admin",
        "course": student["course"] if student else "",
        "class_name": student["class_name"] if student else "",
        "phone": student["phone"] if student else ""
    })


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/admin/dashboard")
@login_required("admin")
def admin_dashboard():
    today = now_sl().strftime("%Y-%m-%d")

    conn = get_db()

    total_students = conn.execute(
        "SELECT COUNT(*) c FROM students"
    ).fetchone()["c"]

    present_today = conn.execute(
        'SELECT COUNT(DISTINCT reg_no) c FROM attendance WHERE date=? AND status="Present"',
        (today,)
    ).fetchone()["c"]

    absent_today = max(total_students - present_today, 0)

    total_records = conn.execute(
        "SELECT COUNT(*) c FROM attendance"
    ).fetchone()["c"]

    recent = conn.execute(
        "SELECT * FROM attendance ORDER BY id DESC LIMIT 5"
    ).fetchall()

    conn.close()

    return render_template(
        "admin/dashboard.html",
        total_students=total_students,
        present_today=present_today,
        absent_today=absent_today,
        total_records=total_records,
        recent=recent
    )


@app.route("/admin/students", methods=["GET", "POST"])
@login_required("admin")
def admin_students():
    conn = get_db()

    if request.method == "POST":
        reg_no = request.form.get("reg_no", "").strip()
        name = request.form.get("name", "").strip()
        course = request.form.get("course", "").strip()
        class_name = request.form.get("class_name", "").strip()
        phone = request.form.get("phone", "").strip()
        password = request.form.get("password", "student123").strip() or "student123"

        if not reg_no or not name:
            conn.close()
            return jsonify({
                "success": False,
                "message": "Reg No and Name are required."
            }), 400

        try:
            cur = conn.cursor()

            cur.execute("""
                INSERT INTO students(reg_no, name, course, class_name, phone)
                VALUES (?, ?, ?, ?, ?)
            """, (reg_no, name, course, class_name, phone))

            student_id = cur.lastrowid

            cur.execute("""
                INSERT INTO users(username, password, role, reg_no)
                VALUES (?, ?, ?, ?)
            """, (
                reg_no,
                generate_password_hash(password),
                "student",
                reg_no
            ))

            conn.commit()

            os.makedirs(os.path.join(DATASET_DIR, str(student_id)), exist_ok=True)

            return jsonify({
                "success": True,
                "student_id": student_id,
                "message": "Student saved. Now capture face dataset."
            })

        except sqlite3.IntegrityError:
            return jsonify({
                "success": False,
                "message": "This Reg No already exists."
            }), 409

        finally:
            conn.close()

    students = conn.execute(
        "SELECT * FROM students ORDER BY id DESC"
    ).fetchall()

    conn.close()

    return render_template("admin/students.html", students=students)


@app.route("/upload_face", methods=["POST"])
@login_required("admin")
def upload_face():
    student_id = request.form.get("student_id")
    image = request.files.get("image")
    image_no = request.form.get("image_no", "0")

    if not student_id or not image:
        return jsonify({
            "success": False,
            "message": "Missing student ID or image."
        }), 400

    frame = decode_image_from_request(image)

    if frame is None:
        return jsonify({
            "success": False,
            "message": "Invalid image."
        }), 400

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (320, 240))

    face = detect_largest_face(gray)

    if face is None:
        return jsonify({
            "success": False,
            "message": "No face detected."
        }), 200

    x, y, w, h = face
    face_img = gray[y:y + h, x:x + w]
    face_img = cv2.resize(face_img, (200, 200))

    student_folder = os.path.join(DATASET_DIR, str(student_id))
    os.makedirs(student_folder, exist_ok=True)

    save_path = os.path.join(student_folder, f"face_{image_no}.jpg")
    cv2.imwrite(save_path, face_img)

    return jsonify({
        "success": True,
        "message": "Face image saved."
    })


@app.route("/train_model", methods=["POST"])
@login_required("admin")
def train_model():
    faces = []
    ids = []

    for student_folder in os.listdir(DATASET_DIR):
        folder_path = os.path.join(DATASET_DIR, student_folder)

        if not os.path.isdir(folder_path):
            continue

        for file_name in os.listdir(folder_path):
            if file_name.lower().endswith((".jpg", ".jpeg", ".png")):
                img_path = os.path.join(folder_path, file_name)
                img = Image.open(img_path).convert("L")
                img_np = np.array(img, "uint8")

                faces.append(img_np)
                ids.append(int(student_folder))

    if len(faces) < 5:
        return jsonify({
            "success": False,
            "message": "Not enough face images. Capture at least 5 images."
        }), 400

    recognizer = create_recognizer()
    recognizer.train(faces, np.array(ids))
    recognizer.write(MODEL_PATH)

    return jsonify({
        "success": True,
        "message": f"Model trained successfully with {len(faces)} images."
    })


@app.route("/admin/records")
@login_required("admin")
def admin_records():
    conn = get_db()

    records = conn.execute(
        "SELECT * FROM attendance ORDER BY id DESC"
    ).fetchall()

    conn.close()

    return render_template("admin/records.html", records=records)


@app.route("/admin/alerts")
@login_required("admin")
def admin_alerts():
    today = now_sl().strftime("%Y-%m-%d")

    conn = get_db()

    absent = conn.execute("""
        SELECT * FROM students
        WHERE reg_no NOT IN (
            SELECT DISTINCT reg_no FROM attendance
            WHERE date=? AND status='Present'
        )
    """, (today,)).fetchall()

    attention = conn.execute("""
        SELECT * FROM attendance
        WHERE attention!='Good'
        ORDER BY id DESC
        LIMIT 20
    """).fetchall()

    location_alerts = conn.execute("""
        SELECT * FROM attendance
        WHERE latitude IS NOT NULL
        AND longitude IS NOT NULL
        AND latitude!=''
        AND longitude!=''
        ORDER BY id DESC
        LIMIT 20
    """).fetchall()

    conn.close()

    return render_template(
        "admin/alerts.html",
        absent=absent,
        attention=attention,
        location_alerts=location_alerts
    )


@app.route("/download_csv")
@login_required("admin")
def download_csv():
    path = os.path.join(APP_DIR, "attendance_export.csv")

    conn = get_db()

    rows = conn.execute("""
        SELECT reg_no, name, date, time, status,
               liveness, attention, confidence, latitude, longitude
        FROM attendance
        ORDER BY id DESC
    """).fetchall()

    conn.close()

    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)

        writer.writerow([
            "Reg No",
            "Name",
            "Date",
            "Time",
            "Status",
            "Liveness",
            "Attention",
            "Confidence",
            "Latitude",
            "Longitude"
        ])

        for r in rows:
            writer.writerow(list(r))

    return send_file(path, as_attachment=True)


@app.route("/student/home")
@login_required("student")
def student_home():
    reg_no = session["reg_no"]

    conn = get_db()

    student = conn.execute(
        "SELECT * FROM students WHERE reg_no=?",
        (reg_no,)
    ).fetchone()

    today = now_sl().strftime("%Y-%m-%d")

    total_records = conn.execute(
        "SELECT COUNT(*) FROM attendance WHERE reg_no=?",
        (reg_no,)
    ).fetchone()[0]

    present_count = conn.execute(
        """
        SELECT COUNT(*)
        FROM attendance
        WHERE reg_no=? AND status='Present'
        """,
        (reg_no,)
    ).fetchone()[0]

    attention_alerts = conn.execute(
        """
        SELECT COUNT(*)
        FROM attendance
        WHERE reg_no=? AND attention!='Good'
        """,
        (reg_no,)
    ).fetchone()[0]

    today_record = conn.execute(
        """
        SELECT *
        FROM attendance
        WHERE reg_no=? AND date=?
        ORDER BY id DESC
        LIMIT 1
        """,
        (reg_no, today)
    ).fetchone()

    conn.close()

    if not student:
        session.clear()
        return redirect(url_for("login"))

    attendance_rate = round((present_count / total_records) * 100) if total_records > 0 else 0
    absent_count = max(total_records - present_count, 0)

    return render_template(
        "student/home.html",
        student=student,
        name=student["name"],
        reg_no=student["reg_no"],
        today_record=today_record,
        current_date=today,
        attendance_rate=attendance_rate,
        present_count=present_count,
        absent_count=absent_count,
        attention_alerts=attention_alerts
    )


@app.route("/student/mark")
@login_required("student")
def student_mark():
    return render_template("student/mark.html")


@app.route("/recognize_face", methods=["POST"])
@login_required("student")
def recognize_face():
    if not os.path.exists(MODEL_PATH):
        return jsonify({
            "recognized": False,
            "message": "Train the model first."
        }), 400

    image = request.files.get("image")
    liveness = request.form.get("liveness", "Not Verified")
    attention = request.form.get("attention", "Not Checked")
    latitude = request.form.get("latitude", "")
    longitude = request.form.get("longitude", "")

    if not image:
        return jsonify({
            "recognized": False,
            "message": "No image received."
        }), 400

    frame = decode_image_from_request(image)

    if frame is None:
        return jsonify({
            "recognized": False,
            "message": "Invalid image."
        }), 400

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (320, 240))

    face = detect_largest_face(gray)

    if face is None:
        return jsonify({
            "recognized": False,
            "message": "No face detected."
        })

    x, y, w, h = face
    face_img = gray[y:y + h, x:x + w]
    face_img = cv2.resize(face_img, (200, 200))

    recognizer = create_recognizer()
    recognizer.read(MODEL_PATH)

    student_id, confidence = recognizer.predict(face_img)
    confidence_value = round(float(confidence), 2)
    print('Recognition confidence:', confidence_value)

    if confidence > 120:
        return jsonify({
            "recognized": False,
            "message": "Unknown face",
            "confidence": confidence_value
        })

    conn = get_db()

    student = conn.execute(
        "SELECT * FROM students WHERE id=?",
        (student_id,)
    ).fetchone()

    if not student:
        conn.close()
        return jsonify({
            "recognized": False,
            "message": "Student not found."
        })

    logged_reg_no = session.get("reg_no")

    if student["reg_no"] != logged_reg_no:
        conn.close()
        return jsonify({
            "recognized": False,
            "message": "This face does not match logged-in student."
        })

    now = now_sl()
    date = now.strftime("%Y-%m-%d")
    time = now.strftime("%H:%M:%S")

    existing = conn.execute(
        """
        SELECT *
        FROM attendance
        WHERE reg_no=? AND date=?
        """,
        (student["reg_no"], date)
    ).fetchone()

    if existing:
        conn.close()
        return jsonify({
            "recognized": True,
            "already": True,
            "message": "Attendance already marked today."
        })

    conn.execute("""
        INSERT INTO attendance
        (
            reg_no,
            name,
            date,
            time,
            status,
            liveness,
            attention,
            confidence,
            image_path,
            latitude,
            longitude
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        student["reg_no"],
        student["name"],
        date,
        time,
        "Present",
        liveness,
        attention,
        confidence_value,
        "",
        latitude,
        longitude
    ))

    conn.commit()
    conn.close()

    return jsonify({
        "recognized": True,
        "message": "Attendance marked successfully.",
        "reg_no": student["reg_no"],
        "name": student["name"],
        "time": time,
        "confidence": confidence_value,
        "latitude": latitude,
        "longitude": longitude
    })


@app.route("/student/records")
@login_required("student")
def student_records():
    reg_no = session["reg_no"]

    conn = get_db()

    records = conn.execute(
        "SELECT * FROM attendance WHERE reg_no=? ORDER BY id DESC",
        (reg_no,)
    ).fetchall()

    conn.close()

    return render_template("student/records.html", records=records)


@app.route("/student/notifications")
@login_required("student")
def student_notifications():
    reg_no = session["reg_no"]

    conn = get_db()

    recent = conn.execute(
        """
        SELECT *
        FROM attendance
        WHERE reg_no=?
        ORDER BY id DESC
        LIMIT 5
        """,
        (reg_no,)
    ).fetchall()

    conn.close()

    return render_template("student/notifications.html", recent=recent)


@app.route("/student/profile")
@login_required("student")
def student_profile():
    reg_no = session["reg_no"]

    conn = get_db()

    student = conn.execute(
        "SELECT * FROM students WHERE reg_no=?",
        (reg_no,)
    ).fetchone()

    conn.close()

    return render_template("student/profile.html", student=student)

@app.route("/api/recognize_face", methods=["POST"])
def api_recognize_face():
    if not os.path.exists(MODEL_PATH):
        return jsonify({"recognized": False, "message": "Train the model first."}), 400

    reg_no = request.form.get("reg_no", "").strip()
    image = request.files.get("image")
    liveness = request.form.get("liveness", "Live Verified")
    attention = request.form.get("attention", "Good")
    latitude = request.form.get("latitude", "")
    longitude = request.form.get("longitude", "")

    if not reg_no:
        return jsonify({"recognized": False, "message": "Missing reg_no."}), 400

    if not image:
        return jsonify({"recognized": False, "message": "No image received."}), 400

    frame = decode_image_from_request(image)

    if frame is None:
        return jsonify({"recognized": False, "message": "Invalid image."}), 400

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (320, 240))

    face = detect_largest_face(gray)

    if face is None:
        return jsonify({"recognized": False, "message": "No face detected."})

    x, y, w, h = face
    face_img = gray[y:y + h, x:x + w]
    face_img = cv2.resize(face_img, (200, 200))

    recognizer = create_recognizer()
    recognizer.read(MODEL_PATH)

    student_id, confidence = recognizer.predict(face_img)
    confidence_value = round(float(confidence), 2)
    print('Recognition confidence:', confidence_value)

    if confidence > 120:
        return jsonify({
            "recognized": False,
            "message": "Unknown face",
            "confidence": confidence_value
        })

    conn = get_db()

    student = conn.execute(
        "SELECT * FROM students WHERE id=?",
        (student_id,)
    ).fetchone()

    if not student:
        conn.close()
        return jsonify({"recognized": False, "message": "Student not found."})

    if student["reg_no"] != reg_no:
        conn.close()
        return jsonify({
            "recognized": False,
            "message": "Face does not match logged-in student."
        })

    now = now_sl()
    date = now.strftime("%Y-%m-%d")
    time = now.strftime("%H:%M:%S")

    existing = conn.execute(
        "SELECT * FROM attendance WHERE reg_no=? AND date=?",
        (student["reg_no"], date)
    ).fetchone()

    if existing:
        conn.close()
        return jsonify({
            "recognized": True,
            "already": True,
            "message": "Attendance already marked today."
        })

    conn.execute("""
        INSERT INTO attendance
        (reg_no, name, date, time, status, liveness, attention, confidence, image_path, latitude, longitude)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        student["reg_no"],
        student["name"],
        date,
        time,
        "Present",
        liveness,
        attention,
        confidence_value,
        "",
        latitude,
        longitude
    ))

    conn.commit()
    conn.close()

    return jsonify({
        "recognized": True,
        "message": "Attendance marked successfully.",
        "reg_no": student["reg_no"],
        "name": student["name"],
        "date": date,
        "time": time,
        "confidence": confidence_value,
        "latitude": latitude,
        "longitude": longitude
    })
@app.route("/api/student_records/<reg_no>")
def api_student_records(reg_no):

    conn = get_db()

    records = conn.execute("""
        SELECT *
        FROM attendance
        WHERE reg_no=?
        ORDER BY id DESC
    """, (reg_no,)).fetchall()

    conn.close()

    return jsonify([
        {
            "date": r["date"],
            "time": r["time"],
            "status": r["status"],
            "confidence": r["confidence"]
        }
        for r in records
    ])
@app.route("/api/student_profile/<reg_no>")
def api_student_profile(reg_no):

    conn = get_db()

    student = conn.execute(
        "SELECT * FROM students WHERE reg_no=?",
        (reg_no,)
    ).fetchone()

    conn.close()

    if not student:
        return jsonify({"success": False})

    return jsonify({
        "success": True,
        "name": student["name"],
        "reg_no": student["reg_no"],
        "course": student["course"],
        "class_name": student["class_name"],
        "phone": student["phone"]
    })
@app.route("/api/student_dashboard/<reg_no>")
def api_student_dashboard(reg_no):

    conn = get_db()

    total = conn.execute(
        "SELECT COUNT(*) c FROM attendance WHERE reg_no=?",
        (reg_no,)
    ).fetchone()["c"]

    present = conn.execute(
        """
        SELECT COUNT(*) c
        FROM attendance
        WHERE reg_no=? AND status='Present'
        """,
        (reg_no,)
    ).fetchone()["c"]

    alerts = conn.execute(
        """
        SELECT COUNT(*) c
        FROM attendance
        WHERE reg_no=? AND attention!='Good'
        """,
        (reg_no,)
    ).fetchone()["c"]

    conn.close()

    rate = round((present / total) * 100) if total > 0 else 0

    return jsonify({
        "attendance_rate": rate,
        "present": present,
        "absent": max(total - present, 0),
        "alerts": alerts
    })
@app.route("/api/student_notifications/<reg_no>")
def api_student_notifications(reg_no):

    conn = get_db()

    recent = conn.execute("""
        SELECT *
        FROM attendance
        WHERE reg_no=?
        ORDER BY id DESC
        LIMIT 10
    """, (reg_no,)).fetchall()

    conn.close()

    notifications = []

    for r in recent:
        notifications.append({
            "title": "Attendance Marked",
            "message": f"Your attendance was marked on {r['date']} at {r['time']}.",
            "type": "success"
        })

        if r["attention"] != "Good":
            notifications.append({
                "title": "Attention Alert",
                "message": f"Attention status: {r['attention']} on {r['date']}.",
                "type": "warning"
            })

    if not notifications:
        notifications.append({
            "title": "No Notifications",
            "message": "You have no attendance notifications yet.",
            "type": "info"
        })

    return jsonify(notifications)
@app.route("/api/admin_dashboard")
def api_admin_dashboard():
    today = now_sl().strftime("%Y-%m-%d")

    conn = get_db()

    total_students = conn.execute(
        "SELECT COUNT(*) c FROM students"
    ).fetchone()["c"]

    present_today = conn.execute(
        "SELECT COUNT(DISTINCT reg_no) c FROM attendance WHERE date=? AND status='Present'",
        (today,)
    ).fetchone()["c"]

    absent_today = max(total_students - present_today, 0)

    total_records = conn.execute(
        "SELECT COUNT(*) c FROM attendance"
    ).fetchone()["c"]

    recent = conn.execute(
        "SELECT reg_no, name, date, time, status FROM attendance ORDER BY id DESC LIMIT 5"
    ).fetchall()

    conn.close()

    return jsonify({
        "total_students": total_students,
        "present_today": present_today,
        "absent_today": absent_today,
        "total_records": total_records,
        "recent": [
            {
                "reg_no": r["reg_no"],
                "name": r["name"],
                "date": r["date"],
                "time": r["time"],
                "status": r["status"]
            }
            for r in recent
        ]
    })
@app.route("/api/admin_students")
def api_admin_students():

    conn = get_db()

    students = conn.execute("""
        SELECT reg_no,name,course,class_name,phone
        FROM students
        ORDER BY name
    """).fetchall()

    conn.close()

    return jsonify([
        {
            "reg_no": s["reg_no"],
            "name": s["name"],
            "course": s["course"],
            "class_name": s["class_name"],
            "phone": s["phone"]
        }
        for s in students
    ])
@app.route("/api/admin_records")
def api_admin_records():

    conn = get_db()

    records = conn.execute("""
        SELECT reg_no,name,date,time,status,
               latitude,longitude,confidence
        FROM attendance
        ORDER BY id DESC
    """).fetchall()

    conn.close()

    return jsonify([
        {
            "reg_no": r["reg_no"],
            "name": r["name"],
            "date": r["date"],
            "time": r["time"],
            "status": r["status"],
            "latitude": r["latitude"],
            "longitude": r["longitude"],
            "confidence": r["confidence"]
        }
        for r in records
    ])
@app.route("/api/admin_alerts")
def api_admin_alerts():

    conn = get_db()

    today = now_sl().strftime("%Y-%m-%d")

    absent = conn.execute("""
        SELECT reg_no,name
        FROM students
        WHERE reg_no NOT IN (
            SELECT reg_no
            FROM attendance
            WHERE date=?
        )
    """, (today,)).fetchall()

    conn.close()

    return jsonify({
        "absent_today": [
            {
                "reg_no": r["reg_no"],
                "name": r["name"]
            }
            for r in absent
        ]
    })
@app.route("/api/export_csv")
def api_export_csv():
    return jsonify({
        "success": True,
        "download_url": "/download_csv"
    })
@app.route("/api/admin_add_student", methods=["POST"])
def api_admin_add_student():
    data = request.get_json(silent=True) or {}

    reg_no = data.get("reg_no", "").strip()
    name = data.get("name", "").strip()
    course = data.get("course", "").strip()
    class_name = data.get("class_name", "").strip()
    phone = data.get("phone", "").strip()
    password = data.get("password", "student123").strip() or "student123"

    if not reg_no or not name:
        return jsonify({"success": False, "message": "Reg No and Name required."}), 400

    conn = get_db()

    try:
        cur = conn.cursor()

        cur.execute("""
            INSERT INTO students(reg_no,name,course,class_name,phone)
            VALUES(?,?,?,?,?)
        """, (reg_no, name, course, class_name, phone))

        student_id = cur.lastrowid

        cur.execute("""
            INSERT INTO users(username,password,role,reg_no)
            VALUES(?,?,?,?)
        """, (
            reg_no,
            generate_password_hash(password),
            "student",
            reg_no
        ))

        conn.commit()

        os.makedirs(os.path.join(DATASET_DIR, str(student_id)), exist_ok=True)

        return jsonify({
            "success": True,
            "student_id": student_id,
            "message": "Student added successfully. Now capture face images."
        })

    except sqlite3.IntegrityError:
        return jsonify({"success": False, "message": "Reg No already exists."}), 409

    finally:
        conn.close()
@app.route("/api/admin_train_model", methods=["POST"])
def api_admin_train_model():
    faces = []
    ids = []

    if not os.path.exists(DATASET_DIR):
        return jsonify({
            "success": False,
            "message": "Dataset folder not found."
        }), 400

    for student_folder in os.listdir(DATASET_DIR):
        folder_path = os.path.join(DATASET_DIR, student_folder)

        if not os.path.isdir(folder_path):
            continue

        try:
            student_id = int(student_folder)
        except ValueError:
            continue

        for file_name in os.listdir(folder_path):
            if file_name.lower().endswith((".jpg", ".jpeg", ".png")):
                img_path = os.path.join(folder_path, file_name)
                face_img = prepare_training_face_from_path(img_path)

                if face_img is not None:
                    faces.append(face_img)
                    ids.append(student_id)

    if len(faces) < 5:
        return jsonify({
            "success": False,
            "message": "Not enough valid images. Capture at least 5 clear face images."
        }), 400

    recognizer = create_recognizer()
    recognizer.train(faces, np.array(ids))
    recognizer.write(MODEL_PATH)

    return jsonify({
        "success": True,
        "message": f"Model trained successfully with {len(faces)} images."
    })


@app.route("/api/admin_upload_face", methods=["POST"])
def api_admin_upload_face():
    student_id = request.form.get("student_id")
    image = request.files.get("image")
    image_no = request.form.get("image_no", "0")

    if not student_id or not image:
        return jsonify({"success": False, "message": "Missing data"}), 400

    student_folder = os.path.join(DATASET_DIR, str(student_id))
    os.makedirs(student_folder, exist_ok=True)

    save_path = os.path.join(student_folder, f"face_{image_no}.jpg")
    image.save(save_path)

    return jsonify({"success": True, "message": "Image saved"})
if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=True)