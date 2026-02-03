import asyncio
import websockets

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

    server = await websockets.serve(handle_client, "0.0.0.0", 8765)
    print("WebSocket server started on port 8765")
    await server.wait_closed()

asyncio.run(main())
