import { clientId } from "sync_client"

export function headers(contentType) {
  return {
    "Content-Type": contentType,
    "Accept": "application/json",
    "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
    "X-Client-Id": clientId
  }
}

export const formHeaders = () => headers("application/x-www-form-urlencoded")
export const jsonHeaders = () => headers("application/json")
