// WebRTC P2P Voice Chat for UNO Show 'Em No Mercy
(function() {
  window.localVoiceStream = null;
  window.peerConnections = {};
  window.isLocalVoiceMuted = false;
  window.voiceAudioContext = null;

  const rtcConfig = {
    iceServers: [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' },
      { urls: 'stun:stun2.l.google.com:19302' },
      { urls: 'stun:stun3.l.google.com:19302' },
      { urls: 'stun:stun4.l.google.com:19302' }
    ]
  };

  function ensureAudioContext() {
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!window.voiceAudioContext && AudioCtx) {
        window.voiceAudioContext = new AudioCtx();
      }
      if (window.voiceAudioContext && window.voiceAudioContext.state === 'suspended') {
        window.voiceAudioContext.resume();
      }
    } catch (e) {
      console.warn("AudioContext init error:", e);
    }
  }

  // Request mic & init local audio stream
  window.initLocalAudio = async function() {
    ensureAudioContext();
    if (window.localVoiceStream && window.localVoiceStream.active) {
      return true;
    }
    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        console.warn("getUserMedia not supported on this browser");
        return false;
      }

      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        },
        video: false
      });

      window.localVoiceStream = stream;
      window.isLocalVoiceMuted = false;
      console.log("Local microphone initialized successfully");

      // Setup audio analyzer for speaking detection
      try {
        if (window.voiceAudioContext) {
          const src = window.voiceAudioContext.createMediaStreamSource(stream);
          const analyser = window.voiceAudioContext.createAnalyser();
          analyser.fftSize = 256;
          src.connect(analyser);
          const dataArray = new Uint8Array(analyser.frequencyBinCount);

          setInterval(function() {
            if (!window.localVoiceStream || window.isLocalVoiceMuted) return;
            analyser.getByteFrequencyData(dataArray);
            let sum = 0;
            for (let i = 0; i < dataArray.length; i++) {
              sum += dataArray[i];
            }
            const avg = sum / dataArray.length;
            const isSpeaking = avg > 20;
            if (typeof window.onSpeakingCallback === 'function') {
              window.onSpeakingCallback(isSpeaking);
            }
          }, 250);
        }
      } catch (e) {
        console.log("Speaking analyzer setup note:", e);
      }

      return true;
    } catch (err) {
      console.error("Microphone permission or access error:", err);
      return false;
    }
  };

  function getOrCreatePeerConnection(peerId, onSignal) {
    if (window.peerConnections[peerId]) {
      return window.peerConnections[peerId];
    }

    const pc = new RTCPeerConnection(rtcConfig);
    window.peerConnections[peerId] = pc;

    // Attach local audio track
    if (window.localVoiceStream) {
      window.localVoiceStream.getAudioTracks().forEach(function(track) {
        pc.addTrack(track, window.localVoiceStream);
      });
    }

    // When ICE candidate is generated
    pc.onicecandidate = function(event) {
      if (event.candidate && typeof onSignal === 'function') {
        onSignal(peerId, 'candidate', JSON.stringify(event.candidate));
      }
    };

    // When remote audio track is received: play in <audio> element
    pc.ontrack = function(event) {
      console.log("Received remote audio track for peer:", peerId);
      ensureAudioContext();

      let audio = document.getElementById('remote_audio_' + peerId);
      if (!audio) {
        audio = document.createElement('audio');
        audio.id = 'remote_audio_' + peerId;
        audio.autoplay = true;
        audio.playsInline = true;
        document.body.appendChild(audio);
      }
      audio.srcObject = event.streams[0];

      const playPromise = audio.play();
      if (playPromise !== undefined) {
        playPromise.catch(function(err) {
          console.warn("Autoplay deferred until user interaction:", err);
          const unlock = function() {
            audio.play();
            document.removeEventListener('click', unlock);
            document.removeEventListener('touchstart', unlock);
          };
          document.addEventListener('click', unlock, { once: true });
          document.addEventListener('touchstart', unlock, { once: true });
        });
      }
    };

    pc.onconnectionstatechange = function() {
      console.log("WebRTC peer", peerId, "state:", pc.connectionState);
    };

    return pc;
  }

  // Caller creates offer
  window.createVoiceOffer = async function(peerId, onSignal) {
    await window.initLocalAudio();
    const pc = getOrCreatePeerConnection(peerId, onSignal);
    try {
      const offer = await pc.createOffer({
        offerToReceiveAudio: true,
        offerToReceiveVideo: false
      });
      await pc.setLocalDescription(offer);
      if (typeof onSignal === 'function') {
        onSignal(peerId, 'offer', JSON.stringify(offer));
      }
    } catch (e) {
      console.error("createVoiceOffer error:", e);
    }
  };

  // Callee receives offer and creates answer
  window.handleVoiceOffer = async function(peerId, offerJson, onSignal) {
    await window.initLocalAudio();
    const pc = getOrCreatePeerConnection(peerId, onSignal);
    try {
      const offer = JSON.parse(offerJson);
      await pc.setRemoteDescription(new RTCSessionDescription(offer));
      const answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      if (typeof onSignal === 'function') {
        onSignal(peerId, 'answer', JSON.stringify(answer));
      }
    } catch (e) {
      console.error("handleVoiceOffer error:", e);
    }
  };

  // Caller receives answer
  window.handleVoiceAnswer = async function(peerId, answerJson) {
    const pc = window.peerConnections[peerId];
    if (!pc) return;
    try {
      const answer = JSON.parse(answerJson);
      if (pc.signalingState !== 'stable') {
        await pc.setRemoteDescription(new RTCSessionDescription(answer));
      }
    } catch (e) {
      console.error("handleVoiceAnswer error:", e);
    }
  };

  // Handling ICE candidates
  window.handleVoiceCandidate = async function(peerId, candidateJson) {
    const pc = window.peerConnections[peerId];
    if (!pc) return;
    try {
      const candidate = JSON.parse(candidateJson);
      await pc.addIceCandidate(new RTCIceCandidate(candidate));
    } catch (e) {
      console.warn("handleVoiceCandidate error:", e);
    }
  };

  // Toggle local mic mute
  window.toggleVoiceMute = function(isMuted) {
    window.isLocalVoiceMuted = isMuted;
    if (window.localVoiceStream) {
      window.localVoiceStream.getAudioTracks().forEach(function(track) {
        track.enabled = !isMuted;
      });
    }
    return isMuted;
  };

  // Disconnect & cleanup
  window.closeAllVoicePeers = function() {
    if (window.peerConnections) {
      for (let id in window.peerConnections) {
        try {
          window.peerConnections[id].close();
        } catch (_) {}
        const audio = document.getElementById('remote_audio_' + id);
        if (audio) {
          audio.pause();
          audio.remove();
        }
      }
      window.peerConnections = {};
    }
    if (window.localVoiceStream) {
      window.localVoiceStream.getTracks().forEach(function(track) {
        track.stop();
      });
      window.localVoiceStream = null;
    }
  };

  // Backward compatibility alias
  window.initVoiceMicrophone = window.initLocalAudio;
})();
