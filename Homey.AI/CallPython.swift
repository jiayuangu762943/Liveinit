//import PythonKit
//
//func callPythonFunctions() {
//    let sys = Python.import("sys")
//    print("Python version: \(sys.version)")
//
//    // Add the directory containing script.py to Python's sys.path
//    let path = "/path/to/your/script" // Replace with the actual path
//    Python.sys.path.append(path)
//
//    // Import the script as a module
//    let script = Python.import("script")
//
//    // Call the add function
//    let sum = script.add(3, 5)
//    print("Sum: \(sum)") // Output: Sum: 8
//
//    // Call the multiply function
//    let product = script.multiply(4, 6)
//    print("Product: \(product)") // Output: Product: 24
//}
//
//// Example usage
//callPythonFunctions()
