const video = document.getElementById("video");
const canvas = document.getElementById("canvas");
const startBtn = document.getElementById("startBtn");
const markBtn = document.getElementById("markBtn");
const resultText = document.getElementById("resultText");
const liveText = document.getElementById("liveText");
const attText = document.getElementById("attText");
const gpsText = document.getElementById("gpsText");

let stream = null;
let camera = null;
let blinkVerified = false;
let attentionStatus = "Checking...";
let eyeWasClosed = false;

function distance(a, b) {
    return Math.abs(a.y - b.y);
}

function checkBlink(landmarks) {
    const leftEye = distance(landmarks[159], landmarks[145]);
    const rightEye = distance(landmarks[386], landmarks[374]);
    const avgEyeOpen = (leftEye + rightEye) / 2;

    if (avgEyeOpen < 0.008) {
        eyeWasClosed = true;
        liveText.innerText = "Blink detected...";
    }

    if (eyeWasClosed && avgEyeOpen > 0.012) {
        blinkVerified = true;
        liveText.innerText = "Live Verified";
    }
}

function checkAttention(landmarks) {
    const nose = landmarks[1];
    const center = landmarks[168];
    const diff = Math.abs(nose.x - center.x);

    if (diff < 0.035) {
        attentionStatus = "Good";
    } else {
        attentionStatus = "Not Attentive";
    }

    attText.innerText = attentionStatus;
}

function getLocation() {
    return new Promise((resolve, reject) => {
        if (!navigator.geolocation) {
            reject(new Error("Location is not supported on this device."));
            return;
        }

        navigator.geolocation.getCurrentPosition(
            (position) => {
                resolve({
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude
                });
            },
            (error) => {
                reject(error);
            },
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 0
            }
        );
    });
}

const faceMesh = new FaceMesh({
    locateFile: (file) => {
        return `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/${file}`;
    }
});

faceMesh.setOptions({
    maxNumFaces: 1,
    refineLandmarks: true,
    minDetectionConfidence: 0.5,
    minTrackingConfidence: 0.5
});

faceMesh.onResults((results) => {
    if (!results.multiFaceLandmarks || results.multiFaceLandmarks.length === 0) {
        liveText.innerText = "No Face";
        attText.innerText = "No Face";
        resultText.innerText = "No face detected. Please face the camera.";
        return;
    }

    const landmarks = results.multiFaceLandmarks[0];

    checkBlink(landmarks);
    checkAttention(landmarks);

    if (!blinkVerified) {
        resultText.innerText = "Please blink once to verify liveness.";
    } else if (attentionStatus !== "Good") {
        resultText.innerText = "Please look directly at the camera.";
    } else {
        resultText.innerText = "Face verified. You can mark attendance.";
    }
});

startBtn?.addEventListener("click", async () => {
    try {
        blinkVerified = false;
        eyeWasClosed = false;
        attentionStatus = "Checking...";

        liveText.innerText = "Blink Required";
        attText.innerText = "Checking...";
        if (gpsText) gpsText.innerText = "Required";
        resultText.innerText = "Starting camera...";

        stream = await navigator.mediaDevices.getUserMedia({
            video: {
                facingMode: "user",
                width: { ideal: 640 },
                height: { ideal: 480 }
            },
            audio: false
        });

        video.srcObject = stream;
        await video.play();

        camera = new Camera(video, {
            onFrame: async () => {
                await faceMesh.send({ image: video });
            },
            width: 640,
            height: 480
        });

        camera.start();

        resultText.innerText = "Camera started. Please blink once.";
    } catch (e) {
        resultText.innerText = "Camera error: " + e.message;
        console.error(e);
    }
});

markBtn?.addEventListener("click", async () => {
    if (!stream) {
        resultText.innerText = "Start camera first.";
        return;
    }

    if (!blinkVerified) {
        resultText.innerText = "Blink first to verify liveness.";
        liveText.innerText = "Not Verified";
        return;
    }

    if (attentionStatus !== "Good") {
        resultText.innerText = "Please look at the camera before marking.";
        return;
    }

    resultText.innerText = "Getting GPS location...";
    if (gpsText) gpsText.innerText = "Checking...";

    let locationData;

    try {
        locationData = await getLocation();
        if (gpsText) gpsText.innerText = "Verified";
    } catch (e) {
        if (gpsText) gpsText.innerText = "Denied";
        resultText.innerText = "Location permission is required to mark attendance.";
        console.error(e);
        return;
    }

    canvas.width = video.videoWidth || 640;
    canvas.height = video.videoHeight || 480;

    const ctx = canvas.getContext("2d");
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    resultText.innerText = "Recognizing face and marking attendance...";

    canvas.toBlob(async (blob) => {
        const fd = new FormData();

        fd.append("image", blob, "face.jpg");
        fd.append("liveness", "Live Verified");
        fd.append("attention", attentionStatus);
        fd.append("latitude", locationData.latitude);
        fd.append("longitude", locationData.longitude);

        try {
            const res = await fetch("/recognize_face", {
                method: "POST",
                body: fd
            });

            const data = await res.json();
            console.log(data);

            resultText.innerText = data.message || "No response from server.";

            if (data.recognized === true) {
                setTimeout(() => {
                    window.location.href = "/student/records";
                }, 1500);
            }
        } catch (e) {
            console.error(e);
            resultText.innerText = "Error: " + e.message;
        }
    }, "image/jpeg", 0.9);
});