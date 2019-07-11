// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"


 
 
 datasets: [
     {
      label: "Total # of Inquiries",
      backgroundColor: "rgba(155, 89, 182,0.2)",
      borderColor: "rgba(142, 68, 173,1.0)",
      pointBackgroundColor: "rgba(142, 68, 173,1.0)",
      data: [inquiry_jan, inquiry_feb, inquiry_mar, inquiry_apr, inquiry_may, inquiry_jun, inquiry_jul, inquiry_aug, inquiry_sep, inquiry_oct, inquiry_nov, inquiry_dec]
     }
]


var ctx = document.getElementById("lineChart").getContext('2d');
var myChart = new Chart(ctx, {
 type: 'line',
  data: {
     labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
   datasets: [
     {
      label: "Total # of Inquiries",
      backgroundColor: "rgba(155, 89, 182,0.2)",
      borderColor: "rgba(142, 68, 173,1.0)",
      pointBackgroundColor: "rgba(142, 68, 173,1.0)",
      data: [inquiry_jan, inquiry_feb, inquiry_mar, inquiry_apr, inquiry_may, inquiry_jun, inquiry_jul, inquiry_aug, inquiry_sep, inquiry_oct, inquiry_nov, inquiry_dec]
     }
    ]
  },
  options: {
   scales: {
    yAxes: [{
     ticks: {
      beginAtZero:true
     }
    }]
   }
  }
});

var inquiry_jan = 0
var inquiry_feb = 0
var inquiry_mar = 0
var inquiry_apr = 0
var inquiry_may = 0
var inquiry_jun = 0
var inquiry_jul = 0
var inquiry_aug = 0
var inquiry_sep = 0
var inquiry_oct = 0
var inquiry_nov = 0
var inquiry_dec = 0
_.map(inquiries_per_month, (i) =>{
   switch(i.month){
    case "Jan":
     inquiry_jan = inquiry_jan + i.count
     break
    case "Feb":
     inquiry_feb = inquiry_feb + i.count
     break
    case "Mar":
     inquiry_mar = inquiry_mar + i.count
     break
    case "Apr":
     inquiry_apr = inquiry_apr + i.count
     break
    case "May":
     inquiry_may = inquiry_may + i.count
     break
    case "Jun":
     inquiry_jun = inquiry_jun + i.count
     break
    case "Jul":
     inquiry_jul = inquiry_jul + i.count
     break
    case "Aug":
     inquiry_aug = inquiry_aug + i.count
     break
    case "Sep":
     inquiry_sep = inquiry_sep + i.count
     break
    case "Oct":
     inquiry_oct = inquiry_oct + i.count
     break
    case "Nov":
     inquiry_nov = inquiry_nov + i.count
     break
    case "Dec":
     inquiry_dec = inquiry_dec + i.count
     break
    default:
     console.log('no inquiries')
  
  }
 });