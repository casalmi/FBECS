#ifndef Vector2I32Type_bas
#define Vector2I32Type_bas

#include once "Vector2I32.bi"

Constructor Vector2I32Type(initX as integer<32>, initY as integer<32>)

    Vec(0) = initX : Vec(1) = initY
    
end constructor

Constructor Vector2I32Type(vector() as integer<32>)
    
    this.Constructor(vector(0), vector(1))

end constructor

Constructor Vector2I32Type(value as integer<32>)
    
    this.Constructor(value, value)
    
end constructor

Constructor Vector2I32Type()
    this.Constructor(0.0, 0.0)
end constructor

sub Vector2I32Type.Normalize()
    
    dim normal as single = 1.0 / sqr(Vec(0) * Vec(0) + _
                                     Vec(1) * Vec(1))
    
    Vec(0) *= normal
    Vec(1) *= normal
    
end sub

function Vector2I32Type.Dot() as single
    
    return (Vec(0)*Vec(0)) + (Vec(1)*Vec(1))
    
end function

function Vector2I32Type.Dot(otherVec as Vector2I32Type) as single
    
    return (Vec(0)*otherVec.Vec(0)) + (Vec(1)*otherVec.Vec(1))
    
end function

function Vector2I32Type.Length() as single
    
    return sqr(this.Dot())
    
end function

function Vector2I32Type.X() as integer<32>
    return this.Vec(0)
end function

function Vector2I32Type.Y() as integer<32>
    return this.Vec(1)
end function

sub Vector2I32Type.SetX(inX as integer<32>)
    this.Vec(0) = inX
end sub

sub Vector2I32Type.SetY(inY as integer<32>)
    this.Vec(1) = inY
end sub

Operator + (ByRef leftSide as Vector2I32Type, ByRef rightSide as Vector2I32Type) as Vector2I32Type
    return Vector2I32Type(leftSide.X()+rightSide.X(), leftSide.Y()+rightSide.Y())
end operator

Operator + (ByRef leftSide as Vector2I32Type, Scalar as integer<32>) as Vector2I32Type
    return Vector2I32Type(leftSide.X()+Scalar, leftSide.Y()+Scalar)
end operator

Operator Vector2I32Type.+=(ByRef rightSide as Vector2I32Type)
    this.Vec(0) += rightSide.Vec(0) : this.Vec(1) += rightSide.Vec(1)
end operator

Operator - (ByRef leftSide as Vector2I32Type, ByRef rightSide as Vector2I32Type) as Vector2I32Type
    return Vector2I32Type(leftSide.X()-rightSide.X(), leftSide.Y()-rightSide.Y())
end operator

Operator - (ByRef leftSide as Vector2I32Type, Scalar as integer<32>) as Vector2I32Type
    return Vector2I32Type(leftSide.X()-Scalar, leftSide.Y()-Scalar)
end operator

'Negate
Operator - (ByRef leftSide as Vector2I32Type) as Vector2I32Type
    return Vector2I32Type(leftSide.X() * -1, leftSide.Y() * -1)
end operator

Operator Vector2I32Type.-=(ByRef rightSide as Vector2I32Type)
    this.Vec(0) -= rightSide.Vec(0) : this.Vec(1) -= rightSide.Vec(1)
end operator

Operator * (ByRef leftSide as Vector2I32Type, ByRef rightSide as Vector2I32Type) as Vector2I32Type
    return Vector2I32Type(leftSide.X()*rightSide.X(), leftSide.Y()*rightSide.Y())
end operator

Operator * (ByRef leftSide as Vector2I32Type, Scalar as integer<32>) as Vector2I32Type
    return Vector2I32Type(leftSide.X()*Scalar, leftSide.Y()*Scalar)
end operator

Operator Vector2I32Type.*=(ByRef rightSide as Vector2I32Type)
    this.Vec(0) *= rightSide.Vec(0) : this.Vec(1) *= rightSide.Vec(1)
end operator

Operator / (ByRef leftSide as Vector2I32Type, ByRef rightSide as Vector2I32Type) as Vector2I32Type
    
    dim divisor(2) as single = {1.0, 1.0}
    
    if (abs(rightSide.X()) > .000001) then
        divisor(0) = rightSide.X()
    end if
    if (abs(rightSide.Y()) > .000001) then
        divisor(1) = rightSide.Y()
    end if
    
    return Vector2I32Type(leftSide.X()/divisor(0), leftSide.Y()/divisor(1))

end operator

Operator / (ByRef leftSide as Vector2I32Type, Scalar as single) as Vector2I32Type

    if abs(Scalar) > 0.000001 then
        return Vector2I32Type(leftSide.X()/Scalar, leftSide.Y()/Scalar)
    else
        return leftSide
    end if

end operator

Operator Vector2I32Type./=(ByRef rightSide as Vector2I32Type)
    if (abs(rightSide.Vec(0)) > .000001) then
        this.Vec(0) /= rightSide.Vec(0)
    end if
    if (abs(rightSide.Vec(1)) > .000001) then
        this.Vec(1) /= rightSide.Vec(1)
    end if
end operator

Operator = (ByRef leftSide as Vector2I32Type, ByRef rightSide as Vector2I32Type) as integer
    return (leftSide.X() = rightSide.X()) AND (leftSide.Y() = rightSide.Y())
end operator

Operator Vector2I32Type.Let(ByRef rightSide as Vector2I32Type)
    this.Vec(0) = rightSide.X() : this.Vec(1) = rightSide.Y()
end operator

Operator Vector2I32Type.Let(value as single)
    this.Vec(0) = value : this.Vec(1) = value
end operator

Operator Vector2I32Type.Let(value as single ptr)
    this.Vec(0) = value[0] : this.Vec(1) = value[1]
end operator

Operator Vector2I32Type.Let(value as integer<32>)
    this.Vec(0) = value : this.Vec(1) = value
end operator

Operator Vector2I32Type.Let(value as integer<64>)
    this.Vec(0) = value : this.Vec(1) = value
end operator

Operator Vector2I32Type.Let(value as uinteger<32>)
    this.Vec(0) = value : this.Vec(1) = value
end operator

Operator Vector2I32Type.Let(value as uinteger<64>)
    this.Vec(0) = value : this.Vec(1) = value
end operator

Operator Vector2I32Type.[] (index as integer) ByRef as integer<32>

    return Vec(index)
    
end operator

Operator Vector2I32Type.cast() as String
    return "("&Vec(0)&", "&Vec(1)&")"
end operator

#endif
