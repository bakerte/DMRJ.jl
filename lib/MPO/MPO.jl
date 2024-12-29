###############################################################################
#
#  Density Matrix Renormalization Group (and other methods) in julia (DMRjulia)
#                               v1.0
#
###############################################################################
# Made by Thomas E. Baker and « les qubits volants » (2024)
# See accompanying license with this program
# This code is native to the julia programming language (v1.10.0+)
#

"""
    mpo = MPO(H[,regtens=false])

constructor for MPO with an array of `TensType` `H`; `regtens` outputs with the julia Array type
"""
function MPO(H::Union{Array{W,1},Memory{W}};regtens::Bool=false) where W <: TensType
  T = typeof(prod(a->eltype(H[a])(1),1:length(H)))
  if !regtens && (typeof(H[1]) <: Array)
    M = [tens{T}(H[a]) for a = 1:length(H)]
  else
    M = H
  end
  return MPO(T,M,regtens=regtens)
end

"""
    cmpo,cpsi = MPS(T,mpo,psi[,oc=1])

Converts `psi` (MPS) and `mpo` (MPO) to type given by `T`
"""
function MPO(type::DataType,psi::MPS,mpo::MPO;regtens::Bool=false,oc::Integer=1)
  return MPO(psi,regtens=regtens,oc=oc,type=type),MPO(mpo,regtens=regtens,oc=oc,type=type)
end

"""
    mpo = MPO(T,H[,regtens=false])

constructor for MPO with an array of `TensType` `H`; can change the element type `T` for the tensors; `regtens` outputs with the julia Array type
"""
function MPO(T::DataType,H::Union{Array{W,1},Memory{W}};regtens::Bool=false) where W <: TensType
  if W <: AbstractArray
    newH = Array{Array{eltype(H[1]),4},1}(undef,size(H,1))
  else
    newH = Array{W,1}(undef,size(H,1))
  end

  for a = 1:size(H,1)
    if ndims(H[a]) == 2
      rP = reshape(H[a],size(H[a],1),size(H[a],2),1,1)
      newH[a] = permutedims(rP,[4,1,2,3])
    else
      newH[a] = H[a]
    end
  end

  if W <: densTensType && !regtens
    finalH = Array{tens{T}}(undef,length(newH))
    for a = 1:length(newH)
      finalH[a] = tens{T}(newH[a])
    end
  elseif W <: qarray
    finalH = [Qtens(T,newH[w]) for w = 1:length(newH)]
  else
    finalH = newH
  end
  
  return matrixproductoperator{eltype(finalH)}(network(finalH))
end

"""
    mpo = MPO(T,H[,regtens=false])

constructor for MPO with a `network` `H`; can change the element type `T` for the tensors; `regtens` outputs with the julia Array type
"""
function MPO(T::DataType,H::network;regtens::Bool=false)
  return MPO(T,H.net,regtens=regtens)
end

"""
    mpo = MPO(T,H[,regtens=false])

constructor for MPO with an MPO `H`; can change the element type `T` for the tensors; `regtens` outputs with the julia Array type
"""
function MPO(T::DataType,mpo::MPO;regtens::Bool=false)
  return MPO(T,mpo.H,regtens=regtens)
end

"""
    mpo = MPO(H[,regtens=false])

constructor for MPO with an MPO `H`; `regtens` outputs with the julia Array type
"""
function MPO(mpo::MPO;regtens::Bool=false)
  return MPO(mpo.H,regtens=regtens)
end

"""
    mpo = MPO(H[,regtens=false])

constructor for MPO with a `network` `H`; `regtens` outputs with the julia Array type
"""
function MPO(mpo::network;regtens::Bool=false)
  return MPO(mpo.net,regtens=regtens)
end

"""
    qmpo = MPO(Qlabels,mpo[,regtens=false])

Creates a quantum number MPO `qmpo` from input `mpo` and `Qlabels`, a vector of `Qnum`

See also: [`Qnum`](@ref)
"""
function MPO(Qlabels::Array{Array{Q,1},1},mpo::MPO) where Q <: Qnum
  qmpo = makeqMPO(Qlabels,mpo)
  return qmpo
end

"""
    qmpo,qmps = MPO(Qlabels,mpo,mps[,newnorm=true,setflux=false,flux=...,randomize=true,override=true,lastfluxzero=false])

Creates a quantum number MPO `qmpo` from input `mpo` and `Qlabels`, a vector of `Qnum`; also returns a quantum number MPS `qmps` from input dense `mps`


# Optional arguments
+ `mps::MPS`: dense MPS
+ `Qlabels::Array{Array{Qnum,1},1}`: quantum number labels on each physical index (assigns physical index labels mod size of this vector)
+ `newnorm::Bool`: set new norm of the MPS tensor
+ `setflux::Bool`: toggle to force this to be the total flux of the MPS tensor
+ `flux::Qnum`: quantum number to force total MPS flux to be if setflux=true
+ `randomize::Bool`: randomize last tensor if flux forces a zero tensor
+ `lastfluxzero::Bool`: determines whether the rightmost flux should be zero or not

See also: [`Qnum`](@ref)
"""
function MPO(Qlabels::Array{Q,1},mpo::MPO,mps::MPS;newnorm::Bool=true,setflux::Bool=false,flux::Q=Q(),randomize::Bool=true,override::Bool=true,lastfluxzero::Bool=false) where Q <: Qnum
  qmpo = makeqMPO([Qlabels],mpo)
  qpsi = makeqMPS([Qlabels],mps,newnorm=newnorm,setflux=setflux,flux=flux,randomize=randomize,override=override,lastfluxzero=lastfluxzero)
  return qmpo,qpsi
end


"""
    qmpo = MPO(Qlabels,mpo)

Creates a quantum number MPO `qmpo` from input `mpo` and `Qlabels`

See also: [`Qnum`](@ref)
"""
function MPO(Qlabels::Array{Q,1},mpo::MPO) where Q <: Qnum
  qmpo = makeqMPO([Qlabels],mpo)
  return qmpo
end


"""
    qmpo,qmps = MPO(Qlabels,mpo,mps[,newnorm=true,setflux=false,flux=...,randomize=true,override=true,lastfluxzero=false])

Creates a quantum number MPO `qmpo` from input `mpo` and an array of quantum number labels `Qlabels`, a vector of `Qnum`; also returns a quantum number MPS `qmps` from input dense `mps`


# Optional arguments
+ `mps::MPS`: dense MPS
+ `Qlabels::Array{Array{Qnum,1},1}`: quantum number labels on each physical index (assigns physical index labels mod size of this vector)
+ `newnorm::Bool`: set new norm of the MPS tensor
+ `setflux::Bool`: toggle to force this to be the total flux of the MPS tensor
+ `flux::Qnum`: quantum number to force total MPS flux to be if setflux=true
+ `randomize::Bool`: randomize last tensor if flux forces a zero tensor
+ `lastfluxzero::Bool`: determines whether the rightmost flux should be zero or not

See also: [`Qnum`](@ref)
"""
function MPO(Qlabels::Array{Array{Q,1},1},mpo::MPO,mps::MPS;newnorm::Bool=true,setflux::Bool=false,flux::Q=Q(),randomize::Bool=true,override::Bool=true,lastfluxzero::Bool=false) where Q <: Qnum
  qmpo = makeqMPO(Qlabels,mpo)
  qpsi = makeqMPS(Qlabels,mps,newnorm=newnorm,setflux=setflux,flux=flux,randomize=randomize,override=override,lastfluxzero=lastfluxzero)
  return qmpo,qpsi
end

