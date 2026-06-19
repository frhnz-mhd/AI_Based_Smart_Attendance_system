const studentForm = document.getElementById("studentForm");
const studentMsg = document.getElementById("studentMsg");
const startCaptureBtn = document.getElementById("startCaptureBtn");
const captureVideo = document.getElementById("captureVideo");
const captureCanvas = document.getElementById("captureCanvas");
const captureStatus = document.getElementById("captureStatus");
const trainBtn = document.getElementById("trainBtn");
const trainMsg = document.getElementById("trainMsg");

let studentId = null;
let captureStream = null;
const maxImages = 30;

console.log("camera_add_student.js loaded");

studentForm.addEventListener("submit", async function (e) {
    e.preventDefault();

    studentMsg.innerText = "Saving student...";

    const fd = new FormData(studentForm);

    try {
        const res = await fetch("/admin/students", {
            method: "POST",
            body: fd
        });

        const data = await res.json();
        console.log("Save response:", data);

        studentMsg.innerText = data.message;

        if (data.success) {
            studentId = data.student_id;
            startCaptureBtn.disabled = false;
            captureStatus.innerText = `Captured 0 / ${maxImages}`;
        }
    } catch (err) {
        console.error(err);
        studentMsg.innerText = "Student save failed. Check terminal.";
    }
});

async function openCamera() {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error("Camera not supported. Use Chrome browser.");
    }

    captureStream = await navigator.mediaDevices.getUserMedia({
        video: {
            facingMode: "user",
            width: { ideal: 640 },
            height: { ideal: 480 }
        },
        audio: false
    });

    captureVideo.srcObject = captureStream;
    await captureVideo.play();
}

async function sendImage(no) {
    captureCanvas.width = 320;
    captureCanvas.height = 240;

    const ctx = captureCanvas.getContext("2d");
    ctx.drawImage(captureVideo, 0, 0, 320, 240);

    return new Promise((resolve) => {
        captureCanvas.toBlob(async (blob) => {
            const fd = new FormData();

            fd.append("student_id", studentId);
            fd.append("image_no", no);
            fd.append("image", blob, `face_${no}.jpg`);

            try {
                const res = await fetch("/upload_face", {
                    method: "POST",
                    body: fd
                });

                const data = await res.json();
                console.log("Face upload:", data);
                resolve(data.success);
            } catch (err) {
                console.error(err);
                resolve(false);
            }
        }, "image/jpeg", 0.85);
    });
}

startCaptureBtn.addEventListener("click", async function () {
    if (!studentId) {
        alert("Save student first.");
        return;
    }

    startCaptureBtn.disabled = true;
    captureStatus.innerText = "Opening camera...";

    try {
        await openCamera();
    } catch (err) {
        console.error("Camera error:", err);
        captureStatus.innerText = err.message;
        startCaptureBtn.disabled = false;
        return;
    }

    let saved = 0;
    let attempts = 0;

    while (saved < maxImages && attempts < 90) {
        attempts++;

        const ok = await sendImage(saved + 1);

        if (ok) {
            saved++;
            captureStatus.innerText = `Captured ${saved} / ${maxImages}`;
        } else {
            captureStatus.innerText = `Face not detected... ${saved}/${maxImages}`;
        }

        await new Promise(resolve => setTimeout(resolve, 350));
    }

    if (captureStream) {
        captureStream.getTracks().forEach(track => track.stop());
    }

    if (saved >= maxImages) {
        captureStatus.innerText = "Face dataset captured successfully ✅";
        studentMsg.innerText = "Now click Train Model.";
    } else {
        captureStatus.innerText = "Could not capture enough images. Try again.";
    }

    startCaptureBtn.disabled = false;
});

trainBtn.addEventListener("click", async function () {
    trainMsg.innerText = "Training model...";

    try {
        const res = await fetch("/train_model", {
            method: "POST"
        });

        const data = await res.json();
        trainMsg.innerText = data.message;
    } catch (err) {
        console.error(err);
        trainMsg.innerText = "Training failed.";
    }
});