#########################################################################
#
#  Density Matrix Renormalization Group (and other methods) in julia (DMRjulia)
#                              v0.8
#
#########################################################################
# Made by Thomas E. Baker (2020)
# See accompanying license with this program
# This code is native to the julia programming language (v1.5.4+)
#

"""
  Module: contractions

Contract two tensors together

See also: [`decompositions`](@ref)
"""
#=
module contractions
using ..tensor
import LinearAlgebra
=#
"""
  C = libmult(C,D[,Z,alpha=,beta=])

Chooses the best matrix multiply function for tensor contraction (dense tensor or sub-block) withoutput matrix `C`

+ Outputs `alpha` * `C` * `D` if `Z` is not input
+ Outputs `alpha` * `C` * `D` + `beta` * `Z` if `Z` is input
"""
@inline function libmult(C::Array{W,2},D::Array{X,2},tempZ::Array{P,2}...;alpha::Number=W(1),beta::Number=W(1)) where {W <: Number, X <: Number, P <: Number}
  if length(tempZ) == 0
    if (eltype(C) == eltype(D)) && !(eltype(C) <: Integer)
      temp_alpha = typeof(alpha) <: eltype(C) ?  alpha : convert(eltype(C),alpha)
      retMat = LinearAlgebra.BLAS.gemm('N','N',temp_alpha,C,D)
    else
      retMat = alpha * C * D
    end
  else
    if (eltype(C) == eltype(D) == eltype(A)) && !(eltype(C) <: Integer)
      temp_alpha = convert(eltype(C),alpha)
      temp_beta = convert(eltype(C),beta)
      LinearAlgebra.BLAS.gemm!('N','N',temp_alpha,C,D,temp_beta,tempZ[1])
      retMat = tempZ[1]
    else
      retMat = alpha * C * D + beta * tempZ[1]
    end
  end
  return retMat
end
export libmult

#       +------------------------+
#>------|    Matrix multiply     |---------<
#       +------------------------+

"""
  C = matrixequiv(X,Lsize,Rsize)

Reshapes tensor `X` into an `Lsize` x `Rsize` matrix with output `C`
"""
function matrixequiv(X::densTensType,Lsize::Integer,Rsize::Integer)
  return matrixequiv!(copy(X),Lsize,Rsize)
end

"""
  C = matrixequiv!(X,Lsize,Rsize)

Reshapes tensor `X` into an `Lsize` x `Rsize` matrix in-place with output `C`
"""
function matrixequiv!(X::Array{W,N},Lsize::Integer,Rsize::Integer) where {W <: Number, N}
  return reshape!(X,Lsize,Rsize)
end

function matrixequiv!(X::denstens,Lsize::Integer,Rsize::Integer)
  return reshape!(X.T,Lsize,Rsize)
end

function permutedims_2matrix!(X::Array{W,N},vec::Tuple,Lsize::Integer,Rsize::Integer) where {W <: Number, N}
  xM = permutedims(X, vec)
  return reshape!(xM,Lsize,Rsize)
end

function permutedims_2matrix!(X::denstens,vec::Tuple,Lsize::Integer,Rsize::Integer)
  return permutedims_2matrix!(makeArray(X),vec,Lsize,Rsize)
end

"""
  C = prepareT(A,Lvec,Rev,conjvar)

Forms the matrix-equivlanet of a tensor `C` defined by `Lvec` indices forming the rows and `Rvec` indices forming the columns; toggle conjugate (`conjvar`)
"""
function prepareT(A::densTensType,Lvec::Tuple,Rvec::Tuple,conjvar::Bool)
  vec = (Lvec...,Rvec...)

  Lsize = length(Lvec) > 0 ? prod(a->size(A,a),Lvec) : 1
  Rsize = length(Rvec) > 0 ? prod(a->size(A,a),Rvec) : 1

  issort = true
  a = 1
  while issort && a < length(Lvec)
    a += 1
    issort = Lvec[a-1] < Lvec[a]
  end
  if length(Rvec) > 0 && length(Lvec) > 0
    issort = issort && Lvec[end] < Rvec[1]
    a = 1
  end
  while issort && a < length(Rvec)
    a += 1
    issort = Rvec[a-1] < Rvec[a]
  end

  if issort
    if eltype(A) <: Complex && conjvar
      out = matrixequiv(A,Lsize,Rsize)
    else
      out = matrixequiv!(A,Lsize,Rsize)
    end
  else
    out = permutedims_2matrix!(A,vec,Lsize,Rsize)
  end
  if conjvar
    conj!(out)
  end
  return out
end

"""
  C = corecontractor(A,iA,B,iB,conjA,conjB,Z...[,alpha=,beta=])

Primary contraction function.  Contracts `A` along indices `iA` to `B` along `iB` to give tensor `C`; toggle conjugation (`conjA` and `conjB`)
"""
function corecontractor(conjA::Bool,conjB::Bool,A::densTensType,iA::intvecType,B::densTensType,iB::intvecType,
                        Z::densTensType...;alpha::Number=eltype(A)(1),beta::Number=eltype(A)(1))
  notvecA = findnotcons(ndims(A),iA)
  C = prepareT(A,notvecA,iA,conjA)
  notvecB = findnotcons(ndims(B),iB)
  D = prepareT(B,iB,notvecB,conjB)

  if length(Z) > 0
    tempZ = reshape(Z[1],size(C,1),size(D,2))
    CD = libmult(C,D,tempZ...,alpha=alpha,beta=beta)
  else
    CD = libmult(C,D,alpha=alpha,beta=beta)
  end

  AAsizes = ()
  for w = 1:length(notvecA)
    AAsizes = (AAsizes...,size(A,notvecA[w]))
  end
  for w = 1:length(notvecB)
    AAsizes = (AAsizes...,size(B,notvecB[w]))
  end
  return CD,AAsizes
end

"""
  C = maincontractor(A,iA,B,iB,conjA,conjB[,Z,alpha=,beta=])

Primary contraction function.  Contracts `A` along indices `iA` to `B` along `iB` to give tensor `C`; toggle conjugation (`conjA` and `conjB`)
"""
function maincontractor(conjA::Bool,conjB::Bool,A::Array,iA::intvecType,B::Array,iB::intvecType,
                          Z::Array...;alpha::Number=eltype(A)(1),beta::Number=eltype(A)(1))
  CD,AAsizes = corecontractor(conjA,conjB,A,iA,B,iB,Z...,alpha=alpha,beta=beta)
  return reshape(CD,AAsizes)
end

"""
  C = maincontractor(A,iA,B,iB,conjA,conjB[,Z,alpha=,beta=])

Primary contraction function.  Contracts `A` along indices `iA` to `B` along `iB` to give tensor `C`; toggle conjugation (`conjA` and `conjB`)
"""
function maincontractor(conjA::Bool,conjB::Bool,A::tens{X},iA::Tuple,B::tens{Y},iB::Tuple,
                        Z::tens{W}...;alpha::Number=eltype(A)(1),
                        beta::Number=eltype(A)(1)) where {X <: Number, Y <: Number, W <: Number}
  CD,AAsizes = corecontractor(conjA,conjB,A,iA,B,iB,Z...,alpha=alpha,beta=beta)
  outType = typeof(X(1)*Y(1))
  nelem = prod(size(CD))
  return tens{outType}(AAsizes,reshape(CD,nelem))
end
export maincontractor

#       +----------------------------+
#>------| Contraction function calls |---------<
#       +----------------------------+


"""


takes `identity` or `adjoint` (or equivalently `conj`) for the `Afct` and `Bfct`

See also: [`identity`](@ref) [`adjoint`](@ref) [`conj`](@ref)
"""
function dot(A::Array,B::Array;Afct::Function=adjoint,Bfct::Function=identity)
  newtypeAB = typeof(eltype(A)(1) * eltype(B)(1))
  val = newtypeAB(0)
  dim1 = length(A)
  @inbounds @simd for j = 1:dim1
    val += Afct(A[j]) * Bfct(B[j])
  end
  return val
end

function dot(A::denstens,B::denstens;Afct::Function=adjoint,Bfct::Function=identity)
  return dot(A.T,B.T,Afct=Afct,Bfct=Bfct)
end

function dot(C::Qtens{W,Q},D::Qtens{R,Q};Afct::Function=adjoint,Bfct::Function=identity) where {W <: Number, R <: Number, Q <: Qnum}
  newtype = typeof(W(1)*R(1))
#  if 
#    return newtype(0)
#  end

  A = changeblock(C,intType[],intType[i for i = 1:length(C.QnumMat)])
  B = changeblock(D,intType[i for i = 1:length(D.QnumMat)],intType[])
  conjA = Afct != identity
  conjB = Bfct != identity
  commonblocks = matchblocks((conjA,conjB),A,B)

  val = newtype(0)
  @inbounds for q = 1:length(commonblocks)
    Aqind = commonblocks[q][1]
    Bqind = commonblocks[q][2]
    val += dot(A.T[Aqind],B.T[Bqind],Afct=Afct,Bfct=Bfct)
  end
  return val
end

"""
  

The function will admit any dimension or input element type in terms of the arrays `A`, `H`, and `B`. However, the function will only work properly when the total elements of `A` times those in `B` equal the elements in `H`

If more operators `H` should be contracted between `A` and `B`, then it is advised here to contract them first before using this function

"""
function dot(A::Array,H::Array,B::Array;Afct::Function=adjoint,Bfct::Function=identity)
  newtypeAHB = typeof(eltype(A)(1) * eltype(H)(1) * eltype(B)(1))
  val = newtypeAHB(0)

  dim1 = length(A)
  dim2 = length(B)
  newtypeAH = typeof(eltype(A)(1) * eltype(H)(1))
  @inbounds for j = 1:dim1
    ival = newtypeAH(0)
    @inbounds @simd for i = 1:dim2
      ival += Afct(A[i]) * H[i + dim1*(j-1)]
    end
    val += ival * Bfct(B[j])
  end
  return val
end

function dot(A::denstens,H::denstens,B::denstens;Afct::Function=adjoint,Bfct::Function=identity)
  return dot(A.T,H.T,B.T,Afct=Afct,Bfct=Bfct)
end

#not sure how to assign matrix blocks...or how to get information from that to A and B vectors
#must be set up correctly with changeblock
function dot(A::Qtens{W,Q},H::Qtens{Y,Q},B::Qtens{R,Q};Afct::Function=adjoint,Bfct::Function=identity) where {W <: Number, Y <: Number, R <: Number, Q <: Qnum}
#  conjA = Afct != identity
#  conjB = Bfct != identity
#  ival = maincontractor(C,G,)
#  A = changeblock(C,intType[],intType[i for i = 1:length(C.QnumMat)])
#  B = changeblock(D,intType[i for i = 1:length(D.QnumMat)],intType[])
#  H = changeblock(G,G.currblock[1],G.currblock[2])
  commonblocks = matchblocks((conjA,false,conjB),A,H,B)
  newtype = typeof(W(1)*R(1))
  val = newtype(0)
  @inbounds for q = 1:length(commonblocks)
    Aqind = commonblocks[q][1]
    Hqind = commonblocks[q][2]
    Bqind = commonblocks[q][3]
    if length(A.T[Aqind]) * length(B.T[Bqind]) != length(H.T[Hqind])
      error("unequal sizes in dot for quantum number tensors for A block: $Aqind, H block: $Hqind, and B block: $Bqind")
    end
    val += dot(A.T[Aqind],H.T[Hqind],B.T[Bqind],Afct=Afct,Bfct=Bfct)
  end
  return val
end
export dot





"""
  C = contract(A,B[,alpha=])

Contracts to (alpha * A * B and returns a scalar output...if only `A` is specified, then the norm is evaluated

See also: [`ccontract`](@ref) [`contractc`](@ref) [`ccontractc`](@ref)
"""
function contract(A::TensType,B::TensType;alpha::Number=eltype(A)(1))
  mA,mB = checkType(A,B)
  return alpha * dot(mA,mB,Afct=identity,Bfct=identity)
end

"""
  ccontract(A,B[,alpha=])

Similar to contract but 'A' is conjugated

See also: ['ccontract'](@ref) ['contractc'](@ref) ['ccontractc'](@ref)
"""
function ccontract(A::TensType,B::TensType;alpha::Number=eltype(A)(1))
  mA,mB = checkType(A,B)
  return alpha * dot(mA,mB,Afct=adjoint,Bfct=identity)
end

"""
  contractc(A,B[,alpha=])

Similar to contract but 'B' is conjugated

See also: ['ccontract'](@ref) ['contractc'](@ref) ['ccontractc'](@ref)
"""
function contractc(A::TensType,B::TensType;alpha::Number=eltype(A)(1))
  mA,mB = checkType(A,B)
  return alpha * dot(mA,mB,Afct=identity,Bfct=adjoint)
end

"""
  ccontractc(A,B[,alpha=])

Similar to contract but 'A' and 'B' are conjugated

See also: ['ccontract'](@ref) ['contractc'](@ref) ['ccontractc'](@ref)
"""
function ccontractc(A::TensType,B::TensType;alpha::Number=eltype(A)(1))
  mA,mB = checkType(A,B)
  return alpha * dot(mA,mB,Afct=adjoint,Bfct=adjoint)
end

"""
    contract(A[,alpha=])

Self-contraction of input tensor `A` to a scalar value of `A`.`A`

See also: ['ccontract'](@ref) ['contractc'](@ref) ['ccontractc'](@ref)
"""
function contract(A::TensType;alpha::Number=eltype(A)(1))
  return alpha * dot(A,A,Afct=identity,Bfct=identity)
end

"""
    ccontract(A[,alpha=])

Self-contraction of input tensor `A` to a scalar value of `A`.`A` with one of the inputs conjugated

See also: ['ccontract'](@ref) ['contractc'](@ref) ['ccontractc'](@ref)
"""
function ccontract(A::TensType;alpha::Number=eltype(A)(1))
  return alpha * dot(A,A,Afct=adjoint,Bfct=identity)
end

"""
    contractc(A[,alpha=])

Self-contraction of input tensor `A` to a scalar value of `A`.`A` with one of the inputs conjugated

See also: ['ccontract'](@ref) ['contractc'](@ref) ['ccontractc'](@ref)
"""
function contractc(A::TensType;alpha::Number=eltype(A)(1))
  return alpha * dot(A,A,Afct=identity,Bfct=adjoint)
end

"""
    ccontractc(A[,alpha=])

Self-contraction of input tensor `A` to a scalar value of `A`.`A` with both inputs conjugated

See also: ['ccontract'](@ref) ['contractc'](@ref) ['contract'](@ref)
"""
function ccontractc(A::TensType;alpha::Number=eltype(A)(1))
  return alpha * dot(A,A,Afct=adjoint,Bfct=adjoint)
end

"""
    contract(A,iA,B,iB[,Z,alpha=,beta=])
Contracts to (alpha * A * B + beta * Z) on input indices `iA` and `iB`; accepts different formats, ex: 1,[1,2],[1 2]); accepts any rank and also Qtensors

# Example:

```julia
julia> A = [1 0;0 -1];B = [-1 0;0 1];Z=[1 0;0 0];
julia> contract(A,2,B,1,Z,alpha=2.,beta=5)
2×2 Array{Float64,2}:
3.0   0.0
0.0  -2.0
```

See also: [`ccontract`](@ref) [`contractc`](@ref) [`ccontractc`](@ref)
"""
function contract(A::TensType,iA::intvecType,B::TensType,iB::intvecType,Z::TensType...;alpha::Number=eltype(A)(1),beta::Number=eltype(A)(1))
  mA,mB = checkType(A,B)
  return maincontractor(false,false,mA,convIn(iA),mB,convIn(iB),Z...,alpha=alpha,beta=beta)
end

"""
    ccontract(A,iA,B,iB[,Z,alpha=,beta=])

Similar to contract but 'A' is conjugated

See also: ['ccontract'](@ref) ['contractc'](@ref) ['ccontractc'](@ref)
"""
function ccontract(A::TensType,iA::intvecType,B::TensType,iB::intvecType,Z::TensType...;alpha::Number=eltype(A)(1),beta::Number=eltype(A)(1))
  mA,mB = checkType(A,B)
  return maincontractor(true,false,mA,convIn(iA),mB,convIn(iB),Z...,alpha=alpha,beta=beta)
end

"""
    contractc(A,iA,B,iB[,Z,alpha=,beta=])

Similar to contract but 'B' is conjugated

See also: ['ccontract'](@ref) ['contractc'](@ref) ['ccontractc'](@ref)
"""
function contractc(A::TensType,iA::intvecType,B::TensType,iB::intvecType,Z::TensType...;alpha::Number=eltype(A)(1),beta::Number=eltype(A)(1))
  mA,mB = checkType(A,B)
  return maincontractor(false,true,mA,convIn(iA),mB,convIn(iB),Z...,alpha=alpha,beta=beta)
end

"""
    ccontractc(A,iA,B,iB[,Z,alpha=,beta=])

Similar to contract but 'A' and 'B' are conjugated

See also: ['ccontract'](@ref) ['contractc'](@ref) ['ccontractc'](@ref)
"""
function ccontractc(A::TensType,iA::intvecType,B::TensType,iB::intvecType,Z::TensType...;alpha::Number=eltype(A)(1),beta::Number=eltype(A)(1))
  mA,mB = checkType(A,B)
  return maincontractor(true,true,mA,convIn(iA),mB,convIn(iB),Z...,alpha=alpha,beta=beta)
end
export contract,ccontract,contractc,ccontractc

"""
    contract(order,A,iA,B,iB[,Z,alpha=,beta=])

Permutes result of [`contract`](@ref) to `order`
"""
function contract(order::intvecType,A::TensType,iA::intvecType,B::TensType,iB::intvecType,Z::TensType...;alpha::Number=eltype(A)(1),beta::Number=1.)
  mA,mB = checkType(A,B)
  newT = contract(mA,iA,mB,iB,Z...,alpha=alpha,beta=beta)
  return permutedims!(newT,convIn(order))
end

"""
    ccontract(order,A,iA,B,iB[,Z,alpha=,beta=])

Permutes result of [`ccontract`](@ref) to `order`
"""
function ccontract(order::intvecType,A::TensType,iA::intvecType,B::TensType,iB::intvecType,Z::TensType...;alpha::Number=eltype(A)(1),beta::Number=eltype(A)(1))
  mA,mB = checkType(A,B)
  newT = ccontract(mA,iA,mB,iB,Z...,alpha=alpha,beta=beta)
  return permutedims!(newT,convIn(order))
end

"""
    contractc(order,A,iA,B,iB[,Z,alpha=,beta=])

Permutes result of [`contractc`](@ref) to `order`
"""
function contractc(order::intvecType,A::TensType,iA::intvecType,B::TensType,iB::intvecType,Z::TensType...;alpha::Number=eltype(A)(1),beta::Number=eltype(A)(1))
  mA,mB = checkType(A,B)
  newT = contractc(mA,iA,mB,iB,Z...,alpha=alpha,beta=beta)
  return permutedims!(newT,convIn(order))
end

"""
    ccontractc(order,A,iA,B,iB[,Z,alpha=,beta=])

Permutes result of [`ccontractc`](@ref) to `order`
"""
function ccontractc(order::intvecType,A::TensType,iA::intvecType,B::TensType,iB::intvecType,Z::TensType...;alpha::Number=eltype(A)(1),beta::Number=eltype(A)(1))
  mA,mB = checkType(A,B)
  newT = ccontractc(mA,iA,mB,iB,Z...,alpha=alpha,beta=beta)
  return permutedims!(newT,convIn(order))
end

"""
    trace(A,iA)

Computes trace of `A` over indices `iA` by first making an identity tensor among those indices; `iA` is a vector of numbers (ex: [1,3]) or a vector of 2-element vectors ([[1,2],[3,4],[5,6]])

# Example:

```julia
julia> A = [1 0;0 -1];
julia> trace(A,[1,2])
0-dimensional Array{Float64,0}:
0.0

julia> A = ones(10,20,10,20);
julia> trace(A,[[1,3],[2,4]])
0-dimensional Array{Float64,0}:
200.0
```
"""
function trace!(A::TensType,iA::Array{NTuple{2,P},1}) where P <: Integer
  Id = makeId(A,iA)
  conL = ntuple(w->iA[w][1],length(iA))
  conR = ntuple(w->iA[w][2],length(iA))
  conA = (conL...,conR...)
  permutedims!(A,conA)
#  conId = ntuple(w->w,ndims(Id))
  return contract(A,Id)
end

function trace!(A::TensType,iA::Array{Array{P,1},1}) where P <: Integer
  return trace!(A,[convIn(iA[w]) for w = 1:length(iA)])
end

function trace!(A::TensType,iA::Array{P,1}...) where P <: Integer
  return trace!(A,[convIn(iA[w]) for w = 1:length(iA)])
end

function trace!(A::TensType)
  return trace!(A,[(1,2)])
end
export trace!

function trace(A::TensType,iA::R...) where R <: Union{Array{P,1},Array{Array{P,1},1},Array{NTuple{2,P},1}} where P <: Integer
  B = copy(A)
  return trace!(B,iA...)
end
export trace



#       +------------------------+
#>------| Quantum number version |---------<
#       +------------------------+

@inline function remQN(Qvec::Array{Array{Q,1},1},vec::intvecType,conjvar::Bool) where Q <: Qnum
  remAQ = Array{Array{Q,1},1}(undef,length(vec))
  @inbounds for q = 1:length(vec)
    currQvec = Qvec[vec[q]]
    remAQ[q] = Q[currQvec[j] for j = 1:length(currQvec)]
  end
  if conjvar
    @inbounds for q = 1:length(remAQ)
      currAQ = remAQ[q]
      for j = 1:length(currAQ)
        currAQ[j] = inv(currAQ[j])
      end
    end
  end
  return remAQ
end

@inline function contractloopZ(outType::DataType,numQNs::Integer,conjA::Bool,conjB::Bool,commonblocks::Array{Array{intType,1},1},A::Qtens{W,Q},B::Qtens{R,Q},
                      Zcommonblocks::Array{Array{intType,1},1},Zed::Qtens{S,Q}...;alpha::Number=eltype(A)(1),beta::Number=eltype(Z[1])(1)) where {W <: Number, R <: Number, S <: Number, Q <: Qnum}

  if length(Z) > 0
    Zone = [i for i = 1:length(notconA)]
    Ztwo = [i + length(notconA) for i = 1:length(notconB)]
    Zed = changeblock(Z[1],Zone,Ztwo)
    Zcommonblocks = matchblocks((conjA,false),A,Zed)
  else
    Zed = Z
  end

  Ablocks = A.currblock[1]
  Bblocks = B.currblock[2]

  newrowcols = Array{NTuple{2,Array{intType,2}},1}(undef,numQNs)
  newQblocksum = Array{NTuple{2,Q},1}(undef,numQNs)
  outTens = Array{Array{outType,2},1}(undef,numQNs)

  #=Threads.@threads=# for q = 1:numQNs
    Aqind = commonblocks[q][1]
    Bqind = commonblocks[q][2]

    if conjA && !(eltype(A.T[Aqind]) <: Real)
      inputA = conj(A.T[Aqind])
    else
      inputA = A.T[Aqind]
    end

    if conjB && !(eltype(B.T[Bqind]) <: Real)
      inputB = conj(B.T[Bqind])
    else
      inputB = B.T[Bqind]
    end


    Zqind = Zcommonblocks[q][2]
    inputZed = Zed.T[Zqind]
    outTens[q] = libmult(inputA,inputB,inputZed,alpha=alpha,beta=beta)

    newrowcols[q] = [A.ind[Aqind][1],B.ind[Bqind][2]]
    newQblocksum[q] = [A.Qblocksum[Aqind][1],B.Qblocksum[Bqind][2]]
  end
  return outTens,newrowcols,newQblocksum
end

@inline function contractloop(outType::DataType,numQNs::Integer,conjA::Bool,conjB::Bool,commonblocks::Array{Array{intType,1},1},
                      A::Qtens{W,Q},B::Qtens{R,Q};alpha::Number=eltype(A)(1)) where {W <: Number, R <: Number, S <: Number, Q <: Qnum}

  Ablocks = A.currblock[1]
  Bblocks = B.currblock[2]

  newrowcols = Array{NTuple{2,Array{intType,2}},1}(undef,numQNs)
  newQblocksum = Array{NTuple{2,Q},1}(undef,numQNs)
  outTens = Array{Array{outType,2},1}(undef,numQNs)

  #=Threads.@threads=# for q = 1:numQNs
    Aqind = commonblocks[q][1]
    Bqind = commonblocks[q][2]

    if conjA && !(eltype(A.T[Aqind]) <: Real)
      inputA = conj(A.T[Aqind])
    else
      inputA = A.T[Aqind]
    end

    if conjB && !(eltype(B.T[Bqind]) <: Real)
      inputB = conj(B.T[Bqind])
    else
      inputB = B.T[Bqind]
    end

    outTens[q] = libmult(inputA,inputB,alpha=alpha)

    newrowcols[q] = (A.ind[Aqind][1],B.ind[Bqind][2])
    if conjA
      LQN = inv(A.Qblocksum[Aqind][1])
    else
      LQN = A.Qblocksum[Aqind][1]
    end
    if conjB
      RQN = inv(B.Qblocksum[Bqind][2])
    else
      RQN = B.Qblocksum[Bqind][2]
    end
    newQblocksum[q] = (LQN,RQN)
  end
  return outTens,newrowcols,newQblocksum
end

function maincontractor(conjA::Bool,conjB::Bool,QtensA::Qtens{W,Q},vecA::Tuple,QtensB::Qtens{R,Q},vecB::Tuple,Z::Qtens{S,Q}...;alpha::Number=W(1),beta::Number=W(1)) where {W <: Number, R <: Number, S <: Number, Q <: Qnum}
    if QtensA === QtensB && ((conjA && W <: Complex) || (conjB && R <: Complex))
      QtensB = copy(QtensA)
    end

    conA,notconA = getinds(QtensA,vecA)
    conB,notconB = getinds(QtensB,vecB)

    A = changeblock(QtensA,notconA,conA)
    B = changeblock(QtensB,conB,notconB)

    commonblocks = matchblocks((conjA,conjB),A,B)

    outType = W == R ? W : typeof(W(1) * R(1))

    numQNs = length(commonblocks)

    if length(Z) > 0
       outTens,newrowcols,newQblocksum = contractloopZ(outType,numQNs,conjA,conjB,commonblocks,A,B,Zcommonblocks,Z...,alpha=alpha,beta=beta)
    else
       outTens,newrowcols,newQblocksum = contractloop(outType,numQNs,conjA,conjB,commonblocks,A,B,alpha=alpha)
    end

    remAQ = A.QnumMat[notconA] #remQN(A.QnumMat,notconA,conjA)
    remBQ = B.QnumMat[notconB] #remQN(B.QnumMat,notconB,conjB)
    newQnumMat = vcat(remAQ,remBQ)

    sumAQ = remQN(A.QnumSum,notconA,conjA)
    sumBQ = remQN(B.QnumSum,notconB,conjB)
    newQnumSum = vcat(sumAQ,sumBQ)

    notvecA = findnotcons(ndims(A),vecA)
    notvecB = findnotcons(ndims(B),vecB)

    newsizeA = [Array{intType,1}(undef,length(QtensA.size[notvecA[w]])) for w = 1:length(notvecA)]
    newsizeB = [Array{intType,1}(undef,length(QtensB.size[notvecB[w]])) for w = 1:length(notvecB)]
    newsize = vcat(newsizeA,newsizeB)
    counter = 0
    @inbounds for w = 1:length(newsize)
      @simd for a = 1:length(newsize[w])
        counter += 1
        newsize[w][a] = counter
      end
    end

     keepers = Bool[size(outTens[q],1) > 0 && size(outTens[q],2) > 0 for q = 1:length(outTens)]

     newflux = conjA ? inv(QtensA.flux) : QtensA.flux
     newflux += conjB ? inv(QtensB.flux) : QtensB.flux

     newcurrblocks = ([i for i = 1:length(notconA)],[i + length(notconA) for i = 1:length(notconB)])

    if sum(keepers) < length(keepers)
      newT = outTens[keepers]
      newinds = newrowcols[keepers]
      newQblocks = newQblocksum[keepers]
    else
      newT = outTens
      newinds = newrowcols
      newQblocks = newQblocksum
    end

     newQtensOutput = Qtens{outType,Q}(newsize,newT,newinds,newcurrblocks,newQblocks,newQnumMat,newQnumSum,newflux)

    return newQtensOutput
end


#         +-----------------+
#>--------|  Check contract |------<
#         +-----------------+


function checkcontract(A::TensType,iA::intvecType,B::TensType,iB::intvecType,Z::TensType...;alpha::Number=eltype(A)(1),beta::Number=eltype(A)(1))
  mA,mB = checkType(A,B)

  if size(mA)[iA] == size(mB)[iB]
    println("contracting over indices with equal sizes")
  else
    error("some indices in A or B are not equal size; A->",size(mA)[iA],", B->",size(mB)[iB])
  end
  if typeof(mA) <: qarray
    println("checking flux left:")
    checkflux(mA)
    println("checking flux right:")
    checkflux(mB)
    for a = 1:length(iA)
      AQNs = recoverQNs(iA[a],A)
      BQNs = recoverQNs(iB[a],B)
      println("contracted index $a (A's index: ",iA[a],", B's index: ",iB[a],")")
      if length(AQNs) == length(BQNs)
        for w = 1:length(AQNs)
          if AQNs[w] != inv(BQNs[w])
            error("unmatching quantum numbers on indices on index ",iA[a]," of A and index ",iB[a]," of B: value ",w)
          end
        end
      else
        error("unmatching quantum number vector lengths")
      end
      println("maching quantum numbers on both indices")
    end
  end
  nothing
end
export checkcontract
#end
