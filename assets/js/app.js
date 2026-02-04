// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Chart from "chart.js/auto"

// Define local hooks
let Hooks = {}

Hooks.PriceChart = {
  mounted() {
    console.log("PriceChart hook mounted", this.el)
    
    try {
      this.chart = new Chart(this.el, {
        type: "line",
        data: { 
          labels: [], 
          datasets: [{ 
            data: [],
            label: 'Price',
            borderColor: 'rgb(34, 197, 94)',
            backgroundColor: 'rgba(34, 197, 94, 0.1)',
            tension: 0.1
          }] 
        },
        options: { 
          animation: false,
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            x: {
              ticks: { color: '#9ca3af' },
              grid: { color: '#374151' }
            },
            y: {
              ticks: { color: '#9ca3af' },
              grid: { color: '#374151' }
            }
          },
          plugins: {
            legend: {
              labels: { color: '#9ca3af' }
            }
          }
        }
      })
      console.log("PriceChart created successfully")

       this.handleEvent("price_update", ({ prices }) => {
         try {
           console.log("[LIVE] price_update event received", prices)
           console.log("Chart instance:", this.chart)
           if (prices && Array.isArray(prices) && prices.length > 0) {
             this.chart.data.labels = prices.map(p => {
               const date = new Date(p.ts)
               return date.toLocaleTimeString()
             })
             this.chart.data.datasets[0].data = prices.map(p => p.price)
             this.chart.update('none')
             console.log("[LIVE] PriceChart updated successfully", this.chart)
           } else {
             console.warn("[LIVE] PriceChart: Invalid or empty prices array", prices)
           }
         } catch (error) {
           console.error("[LIVE] Error in price_update handler:", error, prices, this.chart)
         }
       })
    } catch (error) {
      console.error("Error creating PriceChart:", error)
    }
  },
  
  destroyed() {
    if (this.chart) {
      console.log("Destroying PriceChart")
      this.chart.destroy()
    }
  }
}

Hooks.VolumeChart = {
  mounted() {
    console.log("VolumeChart hook mounted", this.el)
    
    try {
      this.chart = new Chart(this.el, {
        type: "bar",
        data: { 
          labels: [], 
          datasets: [{ 
            data: [],
            label: 'Volume',
            backgroundColor: 'rgba(59, 130, 246, 0.6)',
            borderColor: 'rgb(59, 130, 246)',
            borderWidth: 1
          }] 
        },
        options: { 
          animation: false,
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            x: {
              ticks: { color: '#9ca3af' },
              grid: { color: '#374151' }
            },
            y: {
              ticks: { color: '#9ca3af' },
              grid: { color: '#374151' }
            }
          },
          plugins: {
            legend: {
              labels: { color: '#9ca3af' }
            }
          }
        }
      })
      console.log("VolumeChart created successfully")

      this.handleEvent("volume_update", ({ volumes }) => {
        console.log("volume_update received:", volumes?.length || 0, "volumes", volumes)
        
        if (volumes && Array.isArray(volumes) && volumes.length > 0) {
          try {
            this.chart.data.labels = volumes.map(v => {
              const date = new Date(v.ts)
              return date.toLocaleTimeString()
            })
            this.chart.data.datasets[0].data = volumes.map(v => v.volume)
            this.chart.update('none')
            console.log("VolumeChart updated successfully")
          } catch (error) {
            console.error("Error updating VolumeChart:", error)
          }
        } else {
          console.warn("VolumeChart: Invalid or empty volumes array")
        }
      })
    } catch (error) {
      console.error("Error creating VolumeChart:", error)
    }
  },
  
  destroyed() {
    if (this.chart) {
      console.log("Destroying VolumeChart")
      this.chart.destroy()
    }
  }
}

Hooks.Sparkline = {
  mounted() {
    console.log("Sparkline hook mounted", this.el)
    
    try {
      this.chart = new Chart(this.el, {
        type: "line",
        data: { 
          labels: [], 
          datasets: [{ 
            data: [], 
            borderWidth: 2,
            borderColor: 'rgb(34, 197, 94)',
            pointRadius: 0,
            fill: true,
            backgroundColor: 'rgba(34, 197, 94, 0.1)'
          }] 
        },
        options: {
          plugins: { legend: { display: false } },
          scales: { 
            x: { display: false }, 
            y: { display: false } 
          },
          animation: false,
          responsive: true,
          maintainAspectRatio: false
        }
      })
      console.log("Sparkline created successfully")

      this.handleEvent("spark_update", ({ prices }) => {
        console.log("spark_update received:", prices?.length || 0, "prices")
        
        if (prices && Array.isArray(prices) && prices.length > 0) {
          try {
            this.chart.data.labels = prices.map(p => p.ts)
            this.chart.data.datasets[0].data = prices.map(p => p.price)
            this.chart.update('none')
            console.log("Sparkline updated successfully")
          } catch (error) {
            console.error("Error updating Sparkline:", error)
          }
        } else {
          console.warn("Sparkline: Invalid or empty prices array")
        }
      })
    } catch (error) {
      console.error("Error creating Sparkline:", error)
    }
  },
  
  destroyed() {
    if (this.chart) {
      console.log("Destroying Sparkline")
      this.chart.destroy()
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

console.log("Registered hooks:", Object.keys(Hooks))

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
})

console.log("LiveSocket initialized with hooks")

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

export default Hooks
