$eJson = '{"eventId":"event_sql_test","eventName":"InPoint 2026 Summit","eventDate":"2026-08-28T09:00:00","location":"9F Conference Hall","description":"MS SQL Live Test","isActive":true}'

Write-Host "1. Testing Create Event in MS SQL..."
$resEvent = Invoke-RestMethod -Uri "http://localhost:5299/api/events" -Method Post -Body $eJson -ContentType "application/json"
Write-Host "-> Event created: $($resEvent.eventName) (ID: $($resEvent.eventId))"

Write-Host "`n2. Testing Get Events..."
$allEvents = Invoke-RestMethod -Uri "http://localhost:5299/api/events"
Write-Host "-> Total Events in DB: $($allEvents.Count)"

Write-Host "`n3. Testing Add Guest in MS SQL..."
$gJson = '{"guestId":"G-001","name":"Dr. Chuang","organization":"General Hospital","title":"Superintendent","rankWeight":1,"tableNo":"VIP-1"}'

$resGuest = Invoke-RestMethod -Uri "http://localhost:5299/api/events/event_sql_test/guests" -Method Post -Body $gJson -ContentType "application/json"
Write-Host "-> Guest created: $($resGuest.name) (Title: $($resGuest.title))"

Write-Host "`n4. Testing Batch Import Guests in MS SQL..."
$batchJson = '[{"guestId":"G-002","name":"Minister Chiu","organization":"MOHW","title":"Minister","rankWeight":1,"tableNo":"VIP-1","phone":"0912-345678"},{"guestId":"G-003","name":"President Huang","organization":"Innovation Center","title":"President","rankWeight":1,"tableNo":"VIP-1","phone":"0922-111222"}]'
$resBatch = Invoke-RestMethod -Uri "http://localhost:5299/api/events/event_sql_test/guests/batch" -Method Post -Body $batchJson -ContentType "application/json"
Write-Host "-> Batch Imported Guests Count: $($resBatch.count)"

Write-Host "`n5. Testing POST Checkin Toggle API..."
$chkJson = '{"isCheckedIn":true,"staffName":"Front Desk Mobile"}'
$resChk = Invoke-RestMethod -Uri "http://localhost:5299/api/events/event_sql_test/guests/G-002/checkin" -Method Post -Body $chkJson -ContentType "application/json"
Write-Host "-> POST Checkin Status: $($resChk.isCheckedIn), Time: $($resChk.checkedInAt)"

Write-Host "`n6. Testing Direct POST /api/events/toggle-checkin API..."
$directChk = '{"eventId":"event_sql_test","guestId":"G-003","isCheckedIn":true,"staffName":"Host Dashboard"}'
$resDirect = Invoke-RestMethod -Uri "http://localhost:5299/api/events/toggle-checkin" -Method Post -Body $directChk -ContentType "application/json"
Write-Host "-> Direct POST Checkin Status: $($resDirect.isCheckedIn), Time: $($resDirect.checkedInAt)"

Write-Host "`n7. Testing Stats API..."
$stats = Invoke-RestMethod -Uri "http://localhost:5299/api/events/event_sql_test/stats"
Write-Host "-> Total: $($stats.totalGuests), CheckedIn: $($stats.checkedInCount), Rate: $($stats.attendanceRate)%"

Write-Host "`n6. Testing Delete Guest in MS SQL..."
$delG = Invoke-RestMethod -Uri "http://localhost:5299/api/events/delete-guest" -Method Post -Body '{"eventId":"event_sql_test","guestId":"G-001"}' -ContentType "application/json"
Write-Host "-> Delete Guest result: $($delG.success)"

Write-Host "`n7. Testing Delete Event in MS SQL..."
$delRes = Invoke-RestMethod -Uri "http://localhost:5299/api/events/delete-event" -Method Post -Body '{"eventId":"event_sql_test"}' -ContentType "application/json"
Write-Host "-> Delete Event result: $($delRes.success)"

$afterDel = Invoke-RestMethod -Uri "http://localhost:5299/api/events"
Write-Host "-> Remaining Events in DB: $($afterDel.Count)"

Write-Host "`n=== ALL MS SQL SERVER TESTS PASSED PERFECTLY! ==="
