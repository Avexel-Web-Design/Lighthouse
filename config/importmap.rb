# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "lib/camera_access", to: "lib/camera_access.js"
pin "lib/lighthouse_db", to: "lib/lighthouse_db.js"
pin "chartkick", to: "chartkick.js"
pin "Chart.bundle", to: "Chart.bundle.js"
pin "jsqr" # @1.4.0
pin "lib/qr_payload", to: "lib/qr_payload.js"
pin "lib/selection", to: "lib/selection.js"
pin "lib/toast", to: "lib/toast.js"
pin "qrcode" # @1.5.4
