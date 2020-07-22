const bmp = require("bmp-js"),
	fs = require("fs")


function formatNum(num) {
	num = num.toString(16)
	return ("000" + num).substr(-4)
}

let imgPath = process.argv[2]
let output = process.argv[3]

console.log(imgPath, "=>", output)

let img = fs.readFileSync(imgPath)
let data = bmp.decode(img)


let scale = Math.max(640/data.width, 480/data.height)
let blocks = 640/scale

console.log(scale, blocks)

data = data.data

let str = ""

for (let i=0; i<data.length; i += 4) {
	let x = ((i/4) % blocks)
	let y = Math.floor((i/4) / blocks)

	let pixel = data.slice(i, i+4)
	let blue = pixel[1]
	let green = pixel[2]
	let red = pixel[3]

	blue = Math.round((blue/255) * 3)
	green = Math.round((green/255) * 7)
	red = Math.round((red/255) * 7)

	let color = (red << 5) + (green << 2) + blue;

	color = color + (color << 8)

	x = x * scale
	y = y * scale
	x = formatNum(x)
	y = formatNum(y)



	str += ("DEFW 0x" + y + x + "\n")
	str += ("DEFW 0x" + formatNum(scale) + formatNum(scale) + "\n")
	str += ("DEFW 0x" + formatNum(0) + formatNum(color) + "\n")

}

fs.writeFileSync(output, str)
