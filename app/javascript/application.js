import "@hotwired/turbo-rails"
import "controllers"
import { clientId } from "sync_client"

addEventListener("turbo:before-fetch-request", (event) => {
  event.detail.fetchOptions.headers["X-Client-Id"] = clientId
})
