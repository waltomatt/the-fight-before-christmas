# the-stress-before-christmas
For this piece of university coursework, we had to implement part of a SoC display unit in Verilog and write a test
bench for it. I chose one of the most simple units (a rectangle), but then I wrote a node program to convert a bitmap image into a series of rectangles that got inserted into a (stupidy long - see image.s) ARM source file which was loaded onto a chip connected to the FPGA so that I could display a festive image :)

![The final product](https://github.com/waltomatt/the-stress-before-christmas/blob/master/final-product.JPG?raw=true)

My design used 234 out of 1920 FPGA slices, a utilisation of 12%,
it used 182 slice flip flops (4%).

The complete SoC uses 597 (15%) of the slice registers (438 flip flops, 159 latches)
The number of occupied slices is 801 (41%)

So therefore, we have used 41% of the FPGA in our complete design.

The maximum frequency of our completed design is 83.75MHz


In hindsight, I think that my test environment was quite well designed. At the later stages of development it was so useful to be able to quickly add tests and check against the proper output from the controller program. I was also quite pleased with the ease of porting the test environment from drawing lines to drawing my rectangle. This course also highlighted the importance of a well designed and thorough test environment, as it allowed me to detect faults early on in the development process.


If I were starting again, I would make sure that I wrote a lot more test cases before I even started development of the design. I ran into problems later on where there were subtle errors in drawing rectangles in certain positions that would've been picked up if I had wrote a lot more tests to start with.


I learnt a lot about the complete design and development of SoC chips, about how important the verification stage is (especially with regards to the talk from Apple with how much a mistake can cost).
