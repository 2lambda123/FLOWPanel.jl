#=##############################################################################
# DESCRIPTION
    Definition of methods for post-processing solver results.

# AUTHORSHIP
  * Created by  : Eduardo J. Alvarez
  * Email       : Edo.AlvarezR@gmail.com
  * Date        : Oct 2022
  * License     : MIT License
=###############################################################################

"""
    calcfield_U!(out::Matrix,
                 sourcebody::AbstractBody, targetbody::AbstractBody,
                 controlpoints::Matrix, Uinfs::Matrix; fieldname="U")

Calculate the velocity induced by `sourcebody` on `controlpoints` and save
it as a field of name `fieldname` under `targetbody`. The field includes the
freestream velocity `Uinfs`.

The field is calculated in place and added to `out` (hence, make sure that `out`
starts with all zeroes).
"""
function calcfield_U!(out::Arr1, sourcebody::AbstractBody, targetbody::AbstractBody,
                        controlpoints::Arr2, Uinfs::Arr3; fieldname="U", addfield=true,
                        ) where {   Arr1<:AbstractArray{<:Number,2},
                                    Arr2<:AbstractArray{<:Number,2},
                                    Arr3<:AbstractArray{<:Number,2}}

    # ERROR CASES
    if check_solved(sourcebody)==false
        error("Source body hasn't been solved yet."*
              " Please call `solve(...)` function first.")
    elseif size(controlpoints, 1)!=3 || size(controlpoints, 2)!=targetbody.ncells
        error("Invalid `controlpoints` matrix."*
              " Expected size $((3, targetbody.ncells)); got $(size(controlpoints)).")
    elseif size(Uinfs, 1)!=3 || size(Uinfs, 2)!=targetbody.ncells
        error("Invalid `Uinfs` matrix."*
              " Expected size $((3, targetbody.ncells)); got $(size(Uinfs)).")
    elseif size(out, 1)!=3 || size(out, 2)!=targetbody.ncells
        error("Invalid `out` matrix."*
              " Expected size $((3, targetbody.ncells)); got $(size(out)).")
    end

    # Add freestream
    out .+= Uinfs

    # Add induced velocity at each control point
    Uind!(sourcebody, controlpoints, out)

    # Save field in body
    if addfield
        add_field(targetbody, fieldname, "vector", eachcol(out), "cell")
    end

    return out
end

"""
    calcfield_U!(out::Matrix,
                    sourcebody::AbstractBody, targetbody::AbstractBody;
                    offset=nothing, characteristiclength=nothing, optargs...)

Calculate the velocity induced by `sourcebody` on control points computed
using `offset` and `characteristiclength`, and save it as a field in
`targetbody`. The field includes the freestream velocity stored as field
`\"Uinf\"` in `targetbody`.

The field is calculated in place and added to `out` (hence, make sure that `out`
starts with all zeroes).
"""
function calcfield_U!(out::Arr,
                        sourcebody::AbstractBody, targetbody::AbstractBody;
                        offset=nothing, characteristiclength=nothing,
                        optargs...
                        ) where {Arr<:AbstractArray{<:Number,2}}

    @assert check_field(targetbody, "Uinf") ""*
        "Target body doesn't have freestream field `\"Uinf\"`."*
        " Please call `add_field(targetbody, \"Uinf\", ...)` first."

    Uinfs = hcat(get_field(targetbody, "Uinf")["field_data"]...)

    # Optional arguments for calc_controlpoints
    cp_optargs = (off=offset, characteristiclength=characteristiclength)
    cp_optargs = ((key, val) for (key, val) in pairs(cp_optargs) if val!=nothing)

    # Calculate control points
    normals = calc_normals(targetbody)
    controlpoints = calc_controlpoints(targetbody, normals; cp_optargs...)

    # Calculate field on control points
    calcfield_U!(out, sourcebody, targetbody, controlpoints, Uinfs; optargs...)
end

"""
    calcfield_U(args...; optargs...)

Similar to [`calcfield_U!`](@ref) but without in-place calculation (`out` is not
needed).
"""
function calcfield_U(sourcebody, targetbody, args...; optargs...)
    out = zeros(3, targetbody.ncells)
    return calcfield_U!(out, sourcebody, targetbody, args...; optargs...)
end

"""
    calcfield_Uoff!(args...; optargs...) = calcfield_U(args...; optargs..., fieldname="Uoff")

See documentation of `calcfield_U!(...)`.
"""
calcfield_Uoff!(args...; optargs...) = calcfield_U!(args...; optargs..., fieldname="Uoff")
calcfield_Uoff(args...; optargs...) = calcfield_U(args...; optargs..., fieldname="Uoff")

"""
    calcfield_Cp!(out::Vector, body::AbstractBody, Us, Uref;
                            U_fieldname="U", fieldname="Cp")

Calculate the pressure coefficient
``C_p = 1 - \\left(\\frac{u}{U_\\mathrm{ref}}\\right)^2}``, where is the
velocity `Us` of each control point. The ``C_p`` is saved as a field named
`fieldname`.

The field is calculated in place and added to `out` (hence, make sure that `out`
starts with all zeroes).
"""
function calcfield_Cp!(out::Arr1, body::AbstractBody, Us::Arr2, Uref::Number;
                        fieldname="Cp", addfield=true
                        ) where {Arr1<:AbstractArray{<:Number,1},
                                 Arr2<:AbstractArray{<:Number,2}}

    # Calculate pressure coefficient
    for (i, U) in enumerate(eachcol(Us))
        out[i] += 1 - (norm(U)/Uref)^2
    end

    # Save field in body
    if addfield
        add_field(body, fieldname, "scalar", out, "cell")
    end

    return out
end

"""
    calcfield_Cp!(out::Vector, body::AbstractBody, Uref;
                            U_fieldname="U", fieldname="Cp")

Calculate the pressure coefficient
``C_p = 1 - \\left(\\frac{u}{U_\\mathrm{ref}}\\right)^2}``, where ``u`` is
the velocity field named `U_fieldname` under `body`. The ``C_p`` is saved
as a field named `fieldname`.

The field is calculated in place and added to `out` (hence, make sure that `out`
starts with all zeroes).
"""
function calcfield_Cp!(out, body, Uref; U_fieldname="U", optargs...)
    # Error case
    @assert check_field(body, U_fieldname) ""*
        "Field $(U_fieldname) not found;"*
       " Please run `calcfield_U(args...; fieldname=$(U_fieldname), optargs...)`"

    Us = hcat(get_field(body, U_fieldname)["field_data"]...)

    return calcfield_Cp!(out, body, Us, Uref; optargs...)
end

"""
    calcfield_Cp(args...; optargs...)

Similar to [`calcfield_Cp!`](@ref) but without in-place calculation (`out` is
not needed).
"""
calcfield_Cp(body::AbstractBody, args...; optargs...) = calcfield_Cp!(zeros(body.ncells), body, args...; optargs...)


"""
    calcfield_F!(out::Vector, body::AbstractBody,
                         areas::Vector, normals::Matrix, Us::Matrix,
                         Uinf::Number, rho::Number;
                         fieldname="F")

Calculate the force of each element
``F = - C_p \\frac{\\rho U_\\infty}{2} A \\hat{\\mathbf{n}}``, where ``C_p``is
calculated from the velocity `Us` at each control point, ``A`` is the area of
each element given in `areas`, and ``\\hat{\\mathbf{n}}`` is the normal of each
element given in `normals`. ``F`` is saved as a field named `fieldname`.

The field is calculated in place and added to `out` (hence, make sure that `out`
starts with all zeroes).
"""
function calcfield_F!(out::Arr0, body::AbstractBody,
                         areas::Arr1, normals::Arr2, Us::Arr3,
                         Uinf::Number, rho::Number;
                         addfield=true, fieldname="F"
                         ) where {   Arr0<:AbstractArray{<:Number,2},
                                     Arr1<:AbstractArray{<:Number,1},
                                     Arr2<:AbstractArray{<:Number,2},
                                     Arr3<:AbstractArray{<:Number,2}}

    # Error cases
    @assert size(out, 1)==3 || size(out, 2)==body.ncells ""*
        "Invalid `out` matrix."*
        " Expected size $((3, body.ncells)); got $(size(out))."
    @assert length(areas)==body.ncells ""*
        "Invalid `areas` vector."*
        " Expected length $(body.ncells); got $(length(areas))."
    @assert size(normals, 1)==3 || size(normals, 2)==body.ncells ""*
        "Invalid `normals` matrix."*
        " Expected size $((3, body.ncells)); got $(size(normals))."
    @assert size(Us, 1)==3 || size(Us, 2)==body.ncells ""*
        "Invalid `Us` matrix."*
        " Expected size $((3, body.ncells)); got $(size(Us))."

    # Calculating F = -Cp * 0.5*ρ*u∞^2 * A * hat{n}, where Cp = 1 - (u/u∞)^2
    # we calculate F directly as F = 0.5*ρ*(u^2 - u∞^2) * A * hat{n}
    for (i, (U, area, normal)) in enumerate(zip(eachcol(Us), areas, eachcol(normals)))
        val = 0.5*rho*(norm(U)^2 - Uinf^2) * area
        out[1, i] += val*normal[1]
        out[2, i] += val*normal[2]
        out[3, i] += val*normal[3]
    end

    # Save field in body
    if addfield
        add_field(body, fieldname, "vector", eachcol(out), "cell")
    end

    return out
end

"""
    calcfield_F!(out::Vector, body::AbstractBody,
                            Uinf::Number, rho::Number;
                            U_fieldname="U", optargs...
                         )

Calculate the force of each element
``F = - C_p \\frac{\\rho U_\\infty}{2} A \\hat{\\mathbf{n}}``, where ``C_p``is
calculated from the velocity `Us` field `U_fieldname`, ``A`` is the area of
each element, and ``\\hat{\\mathbf{n}}`` is the normal of each element. ``F``
is saved as a field named `fieldname`.

The field is calculated in place and added to `out` (hence, make sure that `out`
starts with all zeroes).
"""
function calcfield_F!(out::Arr, body::AbstractBody,
                        Uinf::Number, rho::Number;
                        U_fieldname="U", optargs...
                     ) where {Arr<:AbstractArray{<:Number,2}}
    # Error cases
    @assert check_field(body, U_fieldname) ""*
        "Field $(U_fieldname) not found;"*
        " Please run `calcfield_U(args...; fieldname=$(U_fieldname), optargs...)`"

    Us = hcat(get_field(body, U_fieldname)["field_data"]...)
    areas = calc_areas(body)
    normals = calc_normals(body; flipbyCPoffset=true)

    return calcfield_F!(out, body, areas, normals, Us, Uinf, rho; optargs...)
end

"""
    calcfield_F(args...; optargs...)

Similar to [`calcfield_F!`](@ref) but without in-place calculation (`out` is
not needed).
"""
calcfield_F(body::AbstractBody, args...; optargs...) = calcfield_F!(zeros(3, body.ncells), body, args...; optargs...)

"""
    calcfield_sectionalforce!(outf::Matrix, outpos::Vector,
                                        body::Union{NonLiftingBody, AbstractLiftingBody},
                                        controlpoints::Matrix, Fs::Matrix;
                                        dimspan=2, dimchord=1,
                                        spandirection=[0, 1, 0],
                                        fieldname="sectionalforce"
                                        )

Calculate the sectional force (a vectorial force per unit span) along the span.
This is calculated from the force `Fs` and the control points `controlpoints`
and saved as a field named `fieldname`.

The field is calculated in place on `outf` while the spanwise position of each
section is stored under `outpos`.
"""
function calcfield_sectionalforce!(outf::Arr0, outpos::Arr1,
                                    body::Union{NonLiftingBody, AbstractLiftingBody},
                                    controlpoints::Arr2, Fs::Arr3;
                                    dimspan=2, dimchord=1,
                                    spandirection=[0, 1, 0],
                                    fieldname="sectionalforce", addfield=true
                                    ) where {   Arr0<:AbstractArray{<:Number,2},
                                                Arr1<:AbstractArray{<:Number,1},
                                                Arr2<:AbstractArray{<:Number,2},
                                                Arr3<:AbstractArray{<:Number,2}}



    lin, gdims = get_linearindex(body)      # LinearIndex and grid dimensions

    # Error cases
    @assert size(outf, 1)==3 || size(outf, 2)==gdims[dimspan] ""*
        "Invalid `outf` matrix."*
        " Expected size $((3, gdims[dimspan])); got $(size(outf))."
    @assert length(outpos)==gdims[dimspan] ""*
        "Invalid `outpos` matrix."*
        " Expected length $(gdims[dimspan]); got $(length(outpos))."
    @assert size(controlpoints, 1)==3 || size(controlpoints, 2)==body.ncells ""*
        "Invalid `controlpoints` matrix."*
        " Expected size $((3, body.ncells)); got $(size(controlpoints))."
    @assert size(Fs, 1)==3 || size(Fs, 2)==body.ncells ""*
        "Invalid `Fs` matrix."*
        " Expected size $((3, body.ncells)); got $(size(Fs))."

    # Pre-allocate memory
    coor = ones(Int, 3)                     # Cartesian coordinates (indices)
    lincoors = zeros(Int, gdims[dimchord])  # Linear coordinate (index)
    outf .= 0

    # Integrate force in the chordwise direction along the span
    for j in 1:gdims[dimspan] # Iterate over span

        for i in 1:gdims[dimchord] # Iterate over chord

            coor[dimchord] = i
            coor[dimspan] = j
            lincoors[i] = lin[coor...]

            # Add force to this section
            outf[1, j] += Fs[1, lincoors[i]]
            outf[2, j] += Fs[2, lincoors[i]]
            outf[3, j] += Fs[3, lincoors[i]]

        end

        # Calculate span position of this section
        spanpos = mean(dot(spandirection, Xcp)
                        for Xcp in eachcol(view(controlpoints, :, lincoors)))
        outpos[j] = spanpos

    end

    # Convert force to be per unit span
    for j in 1:gdims[dimspan] # Iterate over span
        deltapos =  j==1 ?              outpos[j+1]-outpos[j] :
                    j==length(outpos) ? outpos[j]-outpos[j-1] :
                                        (outpos[j+1]-outpos[j-1])/2

        outf[:, j] /= abs(deltapos)
    end

    # Save field in body
    if addfield
        add_field(body, fieldname, "vector", eachcol(outf), "system")
        add_field(body, fieldname*"-pos", "vector", eachcol(outpos), "system")
    end

    return outf, outpos
end

"""
    calcfield_sectionalforce!(outFs::Matrix, outpos::Vector,
                                    body::Union{NonLiftingBody, AbstractLiftingBody};
                                    F_fieldname="F", optargs...
                                    )

Calculate the sectional force (a vectorial force per unit span) along the span.
This is calculated from the force field `F_fieldname` and saved as a field named
`fieldname`.

The field is calculated in place on `outFs` while the spanwise position of each
section is stored under `outpos`.
"""
function calcfield_sectionalforce!(outFs::Arr0, outpos::Arr1,
                                    body::Union{NonLiftingBody, AbstractLiftingBody};
                                    F_fieldname="F",
                                    offset=nothing, characteristiclength=nothing,
                                    optargs...
                                    ) where {   Arr0<:AbstractArray{<:Number,2},
                                                Arr1<:AbstractArray{<:Number,1}}
    # Error cases
    @assert check_field(body, F_fieldname) ""*
        "Field $(F_fieldname) not found;"*
        " Please run `calcfield_F(args...; fieldname=$(F_fieldname), optargs...)`"

    Fs = hcat(get_field(body, F_fieldname)["field_data"]...)

    # Optional arguments for calc_controlpoints
    cp_optargs = (off=offset, characteristiclength=characteristiclength)
    cp_optargs = ((key, val) for (key, val) in pairs(cp_optargs) if val!=nothing)

    # Calculate control points
    normals = calc_normals(body)
    controlpoints = calc_controlpoints(body, normals; cp_optargs...)

    return calcfield_sectionalforce!(outFs, outpos, body,
                                            controlpoints, Fs; optargs...)
end


"""
    calcfield_sectionalforce(args...; optargs...)

Similar to [`calcfield_sectionalforce!`](@ref) but without in-place calculation
(`outFs` nor `outpos` are needed).
"""
function calcfield_sectionalforce(body::Union{NonLiftingBody, AbstractLiftingBody}, args...;
                                                        dimspan=2, optargs...)

    lin, gdims = get_linearindex(body)      # LinearIndex and grid dimensions

    outFs = zeros(3, gdims[dimspan])
    outpos = zeros(gdims[dimspan])

    return calcfield_sectionalforce!(outFs, outpos, body, args...;
                                                    dimspan=dimspan, optargs...)
end

"""
    calcfield_Ftot!(out::AbstractVector, body::AbstractBody,
                            Fs::AbstractMatrix; fieldname="Ftot")

Calculate the integrated force of this body, which is a three-dimensional vector.
This is calculated from the force of each element given in `Fs` and saved as a
field named `fieldname`.

The field is calculated in place and added to `out`.
"""
function calcfield_Ftot!(out::AbstractVector, body::AbstractBody,
                            Fs::AbstractMatrix; fieldname="Ftot", addfield=true)

    # Error case
    @assert length(out)==3 ""*
        "Invalid `out` vector. Expected length $(3); got $(length(out))."

    for i in 1:3
        out[i] += sum(view(Fs, i, :))
    end

    # Save field in body
    if addfield
        add_field(body, fieldname, "vector", out, "system")
    end

    return out
end

"""
    calcfield_Ftot!(out::AbstractVector, body::AbstractBody;
                                    F_fieldname="F", optargs...)

Calculate the integrated force of this body, which is a three-dimensional vector.
This is calculated from the force field `F_fieldname` and saved as a field named
`fieldname`.

The field is calculated in place and added to `out`.
"""
function calcfield_Ftot!(out, body; F_fieldname="F", optargs...)
    # Error case
    @assert check_field(body, F_fieldname) ""*
        "Field $(F_fieldname) not found;"*
        " Please run `calcfield_F(args...; fieldname=$(F_fieldname), optargs...)`"

    Fs = hcat(get_field(body, F_fieldname)["field_data"]...)

    return calcfield_Ftot!(out, body, Fs; optargs...)
end

"""
    calcfield_Ftot(body, args...; optargs...) = calcfield_Ftot!(zeros(3), body, args...; optargs...)

Similar to [`calcfield_Ftot!`](@ref) but without in-place calculation (`out` is
not needed).
"""
calcfield_Ftot(body, args...; optargs...) = calcfield_Ftot!(zeros(3), body, args...; optargs...)

"""
    calcfield_LDS!(out::Matrix, body::AbstractBody, Fs::Matrix,
                    Lhat::Vector, Dhat::Vector, Shat::Vector)

Calculate the integrated force decomposed as lift, drag, and sideslip according
to the orthonormal basis `Lhat`, `Dhat`, `Shat`.
This is calculated from the force of each element given in `Fs`.
`out[:, 1]` is the lift vector and is saved as the field "L".
`out[:, 2]` is the drag vector and is saved as the field "D".
`out[:, 3]` is the sideslip vector and is saved as the field "S".

The field is calculated in place on `out`.
"""
function calcfield_LDS!(out::AbstractMatrix, body::AbstractBody,
                        Fs::AbstractMatrix,
                        Lhat::AbstractVector, Dhat::AbstractVector,
                        Shat::AbstractVector;
                        addfield=true)
    # Error case
    @assert size(out, 1)==3 || size(out, 2)==3 ""*
        "Invalid `out` matrix. Expected size $((3, 3)); got $(size(out))."
    @assert abs(norm(Lhat) - 1) <= 2*eps() ""*
        "Lhat=$(Lhat) is not a unitary vector"
    @assert abs(norm(Dhat) - 1) <= 2*eps() ""*
        "Dhat=$(Dhat) is not a unitary vector"
    @assert abs(norm(Shat) - 1) <= 2*eps() ""*
        "Shat=$(Shat) is not a unitary vector"

    # Calculate Ftot (integrated force)
    for i in 1:3
        out[i, 3] += sum(view(Fs, i, :))
    end

    # Project Ftot in each direction
    out[:, 1] = Lhat
    out[:, 1] *= dot(view(out, :, 3), Lhat)
    out[:, 2] = Dhat
    out[:, 2] *= dot(view(out, :, 3), Dhat)
    aux = dot(view(out, :, 3), Shat)
    out[:, 3] = Shat
    out[:, 3] *= aux

    # Save field in body
    if addfield
        add_field(body, "L", "vector", view(out, :, 1), "system")
        add_field(body, "D", "vector", view(out, :, 2), "system")
        add_field(body, "S", "vector", view(out, :, 3), "system")
    end

    return out
end

"""
    calcfield_LDS!(out::Matrix, body::AbstractBody,
                    Lhat::Vector, Dhat::Vector, Shat::Vector; F_fieldname="F")

Calculate the integrated force decomposed as lift, drag, and sideslip according
to the orthonormal basis `Lhat`, `Dhat`, `Shat`.
This is calculated from the force field `F_fieldname`.
"""
function calcfield_LDS!(out, body, Lhat, Dhat, Shat; F_fieldname="F", optargs...)
    # Error case
    @assert check_field(body, F_fieldname) ""*
        "Field $(F_fieldname) not found;"*
        " Please run `calcfield_F(args...; fieldname=$(F_fieldname), optargs...)`"

    Fs = hcat(get_field(body, F_fieldname)["field_data"]...)

    return calcfield_LDS!(out, body, Fs, Lhat, Dhat, Shat; optargs...)
end

"""
    calcfield_LDS!(out, body, Lhat, Dhat; optargs...)

`Shat` is calculated automatically from `Lhat` and `Dhat`,
"""
function calcfield_LDS!(out, body, Lhat, Dhat; optargs...)
    return calcfield_LDS!(out, body, Lhat, Dhat, cross(Lhat, Dhat); optargs...)
end


"""
    calcfield_LDS(body, args...; optargs...) = calcfield_LDS!(zeros(3, 3), body, args...; optargs...)

Similar to [`calcfield_LDS!`](@ref) but without in-place calculation (`out` is
not needed).
"""
calcfield_LDS(body, args...; optargs...) = calcfield_LDS!(zeros(3, 3), body, args...; optargs...)
