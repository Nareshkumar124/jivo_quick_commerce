"""Tiny TCP relay for the `db-down` QA profile (qa/tools/instance.sh):

    python tcp_relay.py <listen_port> <target_host> <target_port>

The QA instance connects to its database through 127.0.0.1:<listen_port>; instance.sh stops the
relay once the instance is up, so every later database connection is refused. That is a safe
way to trigger the 500 envelope (P0-TC-09) without touching any shared database. Listens on
127.0.0.1 only. Never prints the target.
"""

import asyncio
import sys


async def _pipe(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    try:
        while data := await reader.read(65536):
            writer.write(data)
            await writer.drain()
    finally:
        writer.close()


async def main(listen: int, host: str, port: int) -> None:
    async def handle(reader, writer):
        try:
            up_reader, up_writer = await asyncio.open_connection(host, port)
        except OSError:
            writer.close()
            return
        await asyncio.gather(_pipe(reader, up_writer), _pipe(up_reader, writer), return_exceptions=True)

    server = await asyncio.start_server(handle, "127.0.0.1", listen)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main(int(sys.argv[1]), sys.argv[2], int(sys.argv[3])))
