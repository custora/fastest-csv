
- For better performance: remove the double pass that occurs in `shift` - we count quotes and then we parse the line.
- Make the functions more flexible so that you can pass an IO object rather than `File::open` arguments
