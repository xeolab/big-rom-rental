# Independent QR check: decode screenshots made by flow.json / print.json (phone/, tablet/, print/ under the given dir).
# uv run --with opencv-python-headless python3 -I eink/test/decode_qr.py /tmp/eink-shots
import sys, cv2
expect = {'phone/03-activate.png':'xeorental://activate?device=ROM-DEMO-0001','phone/11-soon-qr.png':'xeorental://renew?device=ROM-DEMO-0001',
 'phone/12-overdue.png':'xeorental://renew?device=ROM-DEMO-0001','tablet/03-activate.png':'xeorental://activate?device=ROM-DEMO-0001',
 'tablet/11-soon-qr.png':'xeorental://renew?device=ROM-DEMO-0001','tablet/12-overdue.png':'xeorental://renew?device=ROM-DEMO-0001',
 'print/print.png':'xeorental://rent?cabinet=XEO-IMAX-DEMO-01'}
det = cv2.QRCodeDetector(); bad = 0
for f, want in expect.items():
    img = cv2.imread(sys.argv[1] + '/' + f)
    got, pts, _ = det.detectAndDecode(img)
    # also at 1/2 scale: closer to what a phone camera sees from a distance
    small = cv2.resize(img, None, fx=0.5, fy=0.5, interpolation=cv2.INTER_AREA)
    got2, _, _ = det.detectAndDecode(small)
    ok = got == want and got2 == want
    bad += not ok
    print(('OK  ' if ok else 'FAIL'), f, repr(got), '| half-scale', repr(got2))
sys.exit(1 if bad else 0)
