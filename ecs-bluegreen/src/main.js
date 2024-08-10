const express = require('express')
const app = express()

app.get('/api/whoami', (req, res) => {
  res.send({
    label: 'blue'
  })
})

app.get('/healthz', (req, res) => {
  res.send({
    success: true
  })
})

app.listen(8080, () => {
  console.log('Server is now on :8080')
})

process.on('SIGINT', () => {
  process.exit(0)
})
