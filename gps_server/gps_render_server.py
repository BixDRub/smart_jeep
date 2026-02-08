import asyncio
import websockets
import os

connected = set()

async def handle_client(websocket):
    connected.add(websocket)
    print(f"Client connected: {websocket.remote_address}")
    try:
        async for message in websocket:
            print(f"Received: {message}")
            for conn in connected:
                if conn != websocket:
                    await conn.send(message)
    except websockets.ConnectionClosed:
        pass
    finally:
        connected.remove(websocket)
        print(f"Client disconnected: {websocket.remote_address}")

async def main():
    port = int(os.environ.get("PORT", 8765))
    server = await websockets.serve(handle_client, "0.0.0.0", port)
    print(f"WebSocket server started on port {port}")
    await server.wait_closed()

asyncio.run(main())
