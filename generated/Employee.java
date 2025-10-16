package com.example.hr;

public class Employee {

    private long employeeId;
    private String name;
    private String department;
    private double salary;

    public long getEmployeeId() {
        return employeeId;
    }
    public String getName() {
        return name;
    }
    public String getDepartment() {
        return department;
    }
    public double getSalary() {
        return salary;
    }

    public void setEmployeeId(long employeeId) {
        this.employeeId = employeeId;
    }
    public void setName(String name) {
        this.name = name;
    }
    public void setDepartment(String department) {
        this.department = department;
    }
    public void setSalary(double salary) {
        this.salary = salary;
    }
}
