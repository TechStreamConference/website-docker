#!/bin/bash

apache2-foreground &

cd frontend/
npm run check
npm run dev &

# Wait for any process to exit
wait -n
# Exit with status of process that exited first
exit $?
