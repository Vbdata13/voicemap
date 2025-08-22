#!/usr/bin/env python3
"""
LiveKit Agent for VoiceMap
Bridges LiveKit WebRTC audio to OpenAI Realtime API
"""

import asyncio
import json
import logging
import os
import websockets
import base64
from dataclasses import dataclass
from typing import Optional
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

from livekit import rtc
from livekit.agents import AutoSubscribe, JobContext, WorkerOptions, cli

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class OpenAIRealtimeConfig:
    """Configuration for OpenAI Realtime API"""
    api_key: str
    model: str = "gpt-4o-realtime-preview-2024-10-01"
    voice: str = "alloy"
    temperature: float = 0.7

class VoiceMapAgent:
    """Main agent that bridges LiveKit and OpenAI"""
    
    def __init__(self):
        self.room: Optional[rtc.Room] = None
        self.openai_api_key = os.getenv("OPENAI_API_KEY")
        
        if not self.openai_api_key:
            raise ValueError("OPENAI_API_KEY environment variable required")
        
        logger.info("🤖 VoiceMap Agent initialized")
        logger.info(f"🔑 OpenAI API key: {self.openai_api_key[:20]}...")
    
    async def handle_participant_connected(self, participant: rtc.RemoteParticipant):
        """Handle new participant joining"""
        logger.info(f"👤 Participant connected: {participant.identity}")
        
        # Send a welcome message
        welcome_msg = "🎙️ Welcome to VoiceMap! LiveKit agent is connected and ready."
        if self.room:
            await self.room.local_participant.publish_data(
                welcome_msg.encode('utf-8'), 
                topic="welcome"
            )
    
    async def handle_audio_received(self, audio_frame: rtc.AudioFrame):
        """Handle incoming audio from participant"""
        logger.info(f"🎵 Received audio frame: {len(audio_frame.data)} bytes")
        
        # For now, just log that we received audio
        # In a full implementation, this would forward to OpenAI Realtime API
        
    async def handle_data_received(self, data: bytes, participant: rtc.RemoteParticipant):
        """Handle data messages from participants"""
        try:
            message = data.decode('utf-8')
            logger.info(f"📨 Received data from {participant.identity}: {message}")
            
            # Echo back a response
            response = f"Agent received: {message}"
            if self.room:
                await self.room.local_participant.publish_data(
                    response.encode('utf-8'), 
                    topic="agent_response"
                )
        except Exception as e:
            logger.error(f"Error handling data message: {e}")

async def entrypoint(ctx: JobContext):
    """Main entrypoint for the LiveKit agent"""
    logger.info("🚀 VoiceMap Agent starting...")
    logger.info(f"🏠 Joining room: {ctx.room.name}")
    
    # Create the agent
    agent = VoiceMapAgent()
    agent.room = ctx.room
    
    # Handle room events
    @ctx.room.on("participant_connected")
    def on_participant_connected(participant: rtc.RemoteParticipant):
        logger.info(f"Participant {participant.identity} connected")
        asyncio.create_task(agent.handle_participant_connected(participant))
    
    @ctx.room.on("track_subscribed")
    def on_track_subscribed(
        track: rtc.Track,
        publication: rtc.RemoteTrackPublication,
        participant: rtc.RemoteParticipant,
    ):
        if track.kind == rtc.TrackKind.KIND_AUDIO:
            logger.info(f"🎤 Subscribed to audio track from {participant.identity}")
            
            # Create audio stream
            audio_stream = rtc.AudioStream(track)
            
            # Handle audio frames
            @audio_stream.on("frame_received")
            def on_audio_frame(frame: rtc.AudioFrame):
                asyncio.create_task(agent.handle_audio_received(frame))
    
    @ctx.room.on("data_received")
    def on_data_received(data: bytes, participant: rtc.RemoteParticipant):
        asyncio.create_task(agent.handle_data_received(data, participant))
    
    logger.info("✅ VoiceMap Agent ready!")
    logger.info("🎯 Waiting for iOS app to connect...")
    
    # Connect to the room to receive events
    await ctx.connect()

if __name__ == "__main__":
    # Set up CLI
    cli.run_app(
        WorkerOptions(
            entrypoint_fnc=entrypoint,
        )
    )