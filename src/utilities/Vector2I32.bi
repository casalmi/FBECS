#ifndef Vector2I32Type_bi
#define Vector2I32Type_bi

type Vector2I32Type
    
    public:
        
        declare Constructor(initX as integer<32>, initY as integer<32>)
        declare Constructor(vector() as integer<32>)
        declare Constructor(value as integer<32>)
        declare Constructor()
        
        declare sub Normalize()
        
        declare function Dot overload () as single
        declare function Dot          (otherVec as Vector2I32Type) as single
        
        declare function Length() as single
        
        declare function X() as integer<32>
        declare function Y() as integer<32>
        
        declare sub SetX(inX as integer<32>)
        declare sub SetY(inY as integer<32>)
        
        declare Operator += (ByRef rightSide as Vector2I32Type)
        declare Operator -= (ByRef rightSide as Vector2I32Type)
        
        declare Operator *= (ByRef rightSide as Vector2I32Type)
        declare Operator /= (ByRef rightSide as Vector2I32Type)
        
        declare Operator Let (ByRef rightSide as Vector2I32Type)
        declare Operator Let (value as single)
        declare Operator Let (value as single ptr)
        declare Operator Let (value as integer<32>)
        declare Operator Let (value as integer<64>)
        declare Operator Let (value as uinteger<32>)
        declare Operator Let (value as uinteger<64>)
        
        declare Operator [] (index as integer) ByRef as integer<32>
        
        declare Operator Cast() as String
        
    private:
    
        dim Vec(1) as integer<32>
    
end type

declare Operator + (ByRef leftSide as Vector2I32Type, ByRef rightSide as Vector2I32Type) as Vector2I32Type
declare Operator + (ByRef leftSide as Vector2I32Type, Scalar as integer<32>) as Vector2I32Type
declare Operator - (ByRef leftSide as Vector2I32Type, ByRef rightSide as Vector2I32Type) as Vector2I32Type
declare Operator - (ByRef leftSide as Vector2I32Type, Scalar as integer<32>) as Vector2I32Type
declare Operator - (ByRef leftSide as Vector2I32Type) as Vector2I32Type
declare Operator * (ByRef leftSide as Vector2I32Type, ByRef rightSide as Vector2I32Type) as Vector2I32Type
declare Operator * (ByRef leftSide as Vector2I32Type, Scalar as integer<32>) as Vector2I32Type
declare Operator / (ByRef leftSide as Vector2I32Type, ByRef rightSide as Vector2I32Type) as Vector2I32Type
declare Operator / (ByRef leftSide as Vector2I32Type, Scalar as single) as Vector2I32Type
declare Operator = (ByRef leftSide as Vector2I32Type, ByRef rightSide as Vector2I32Type) as integer

#endif
