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
#=
module optimizeMPS
#using ..shuffle
using ..tensor
using ..QN
using ..Qtensor
#using ..Qtask
using ..MPutil
using ..MPmaker
using ..contractions
using ..decompositions
=#
"""
    TNparams

parameters of a tensor network calculation
"""
abstract type TNparams end
export TNparams

"""
    algvars

Struct to hold variables for the MPS optimization function and others
"""
mutable struct algvars{W <: Number,Q <: Qnum} <: TNparams
  load::Bool
  method::String
  parallel_method::String
  nsites::Integer
  minm::Integer
  maxm::Integer
  cutoff::Float64

  sweeps::Integer
  halfsweep::Bool

  maxiter::Integer
  mincr::Integer
  cvgE::Bool
  goal::W
  startnoise::Float64
  noise::Union{Array{Float64,1},Float64}
  noise_goal::Float64
  noise_decay::Float64
  noise_incr::Float64

  exnum::Integer
  cushion::Integer

  shift::Bool
  fixD::Bool

  startoc::Integer
  origj::Bool

  maxshowD::Integer

  storeD::Array{Float64,1}
  saveEnergy::Array{W,1}

  energy::Union{Array{W,1},W}
  lastenergy::Union{Array{W,1},W}

  entropy::Union{Array{Float64,1},Float64}
  lastentropy::Union{Array{Float64,1},Float64}

  truncerr::Float64
  maxtrunc::Float64
  biggestm::Integer
  savebiggestm::Integer

  SvNbond::Union{Integer,Array{Integer,1}}
  allSvNbond::Bool

  Lbound::TensType
  Rbound::TensType
  Lenv::Env
  Renv::Env

  psiLenv::Env
  psiRenv::Env

  sparematrix::TensType
  saveQ::Array{Q,1}

  efficient::Bool
  silent::Bool
  qselect::Array{Tuple{Integer,Q},1}
  partitions::Integer
end
export algvars
#=
function params(params::algvars{W,Q}) where {W <: Number, Q <: Qnum}

  return algvars{W,Q}(params.load,params.method,params.parallel_method,params.nsites,params.minm,params.maxm,params.cutoff,params.sweeps,params.halfsweep,params.maxiter,params.mincr,params.cvgE,params.goal,params.startnoise,params.noise,params.noise_goal,params.noise_decay,params.noise_incr,params.exnum,params.cushion,params.shift,params.fixD,params.startoc,params.origj,params.maxshowD,params.storeD,params.saveEnergy,params.energy,params.lastenergy,params.entropy,params.lastentropy,params.truncerr,params.maxtrunc,params.biggestm,params.savebiggestm,params.SvNbond,params.allSvNbond,params.Lbound,params.Rbound,params.Lenv,params.Renv,params.psiLenv,params.psiRenv,params.sparematrix,params.saveQ,params.efficient,params.silent,params.qselect,params.partitions)
end
=#
function algvars(params::algvars{W,Q}) where {W <: Number, Q <: Qnum}
  return algvars{W,Q}(params.load,params.method,params.parallel_method,params.nsites,params.minm,params.maxm,params.cutoff,params.sweeps,params.halfsweep,params.maxiter,params.mincr,params.cvgE,params.goal,params.startnoise,params.noise,params.noise_goal,params.noise_decay,params.noise_incr,params.exnum,params.cushion,params.shift,params.fixD,params.startoc,params.origj,params.maxshowD,params.storeD,params.saveEnergy,params.energy,params.lastenergy,params.entropy,params.lastentropy,params.truncerr,params.maxtrunc,params.biggestm,params.savebiggestm,params.SvNbond,params.allSvNbond,params.Lbound,params.Rbound,params.Lenv,params.Renv,params.psiLenv,params.psiRenv,params.sparematrix,params.saveQ,params.efficient,params.silent,params.qselect,params.partitions)
end

import Base.println
function println(params::TNparams)
  println("load = ",params.load)
  println("method = ",params.method)
  println("parallel_method = ",params.parallel_method)
  println("nsites = ",params.nsites)
  println("minm = ",params.minm)
  println("maxm = ",params.maxm)
  println("cutoff = ",params.cutoff)
  println("sweeps = ",params.sweeps)
  println("halfsweeps = ",params.halfsweep)
  println("maxiter = ",params.maxiter)
  println("goal = ",params.goal)
  println("startnoise = ",params.startnoise)
  println("noise = ",params.noise)
  println("noise_goal = ",params.noise_goal)
  println("noise_decay = ",params.noise_decay)
  println("noise_incr = ",params.noise_incr)
  println("exnum = ",params.exnum)
  println("cushion = ",params.cushion)
  println("shift = ",params.shift)
  println("fixD = ",params.fixD)
  println("startoc = ",params.startoc)
  println("origj = ",params.origj)
  println("maxshowD = ",params.maxshowD)
  println("storeD = ",params.storeD)
  println("saveEnergy = ",params.saveEnergy)
  println("energy = ",params.energy)
  println("lastenergy = ",params.lastenergy)
  println("entropy = ",params.entropy)
  println("lastentropy = ",params.lastentropy)
  println("truncerr = ",params.truncerr)
  println("maxtrunc = ",params.maxtrunc)
  println("biggestm = ",params.biggestm)
  println("SvNbond = ",params.SvNbond)
  println("allSvNbond = ",params.allSvNbond)
  #=
  println("Lbound = ",params.Lbound)
  println("Rbound = ",params.Rbound)
  println("Lenv = ",params.Lenv)
  println("Renv = ",params.Renv)
  =#
  println("efficient = ",params.efficient)
  println("silent = ",params.silent)
  println("qselect = ",params.qselect)
  println("partitions = ",params.partitions)
  println()
  nothing
end

function optinformation(params::TNparams)
  if !params.silent
    println("Optimizing matrix product state...")
    println("  algorithm = ",params.method)
    println("  size of renormalized system = ",params.nsites)
    println("  minimum bond dimension = ",params.minm)
    println("  maximum bond dimension = ",params.maxm)
    println("  number of sweeps = ",params.sweeps)
    println("  Krylov iterations = ",params.maxiter)
    println("  cutoff = ",params.cutoff)
    println("  converge in energy? ",params.cvgE," (otherwise, entropy)")
    println("  converging first ",params.exnum-params.cushion," values")
    println("  specified goal = ",params.goal)
    println("  initial noise parameter = ",params.noise)
    println("  noise increment = ",params.noise_incr)
  end
  nothing
end

function setEnv(dualpsi::MPS,psi::MPS,mpo::MPO,params::TNparams,
                prevpsi::MPS...;measfct::Function=expect,mover::Function=move!)

#  println()
#  println("setEnv:")
#  println()

#  println(params.Lbound)
#  println(params.Rbound)

#  checkflux(params.Lbound)
#  checkflux(params.Rbound)

#  println(params.Lenv == [0])
#  println(params.Renv == [0])

  if params.Lenv == [0] && params.Renv == [0]
    params.Lenv,params.Renv = makeEnv(dualpsi,psi,mpo,Lbound=params.Lbound,Rbound=params.Rbound)
    #=
  else  

    for a = 1:length(params.Renv)
      println(a)
      checkflux(params.Renv[a])
    end

    for a = 1:length(params.Lenv)
      println(a)
      checkflux(params.Lenv[a])
    end
    =#
  end

  SvN,lastSvN,maxtrunc,biggestm = [0.],[0.],[0.],[0]
  params.lastentropy = copy(params.entropy)
  if length(params.noise) != params.exnum
    params.noise = [params.noise[1] for i = 1:params.exnum]
  end
  Ns = length(psi)
  timer = 0.

  Nsteps = Ns-1
  if !params.halfsweep
    Nsteps *= 2
  end

  # setup for the sweeping direction
  if psi.oc == 1
    j = 1
  elseif psi.oc == Ns #
    j = -1
  else
    j = params.origj ? 1 : -1 #if the oc is away from the edge, j could be externally specified.
  end

  if params.allSvNbond
    SvNvec = zeros(Ns)
  else
    SvNvec = zeros(0)
  end
  startoc = copy(psi.oc)

  if isapprox(sum(params.energy),0.) && !params.efficient
    currLenv = params.Lenv[1]
    currRenv = params.Renv[Ns]
    outmeas = measfct(dualpsi,psi,mpo,Lbound=currLenv,Rbound=currRenv)
    params.energy = real(outmeas)
  end
  params.lastenergy = copy(params.energy)

  if !params.cvgE && params.allSvNbond && length(psi) != length(params.entropy)
    params.entropy = zeros(length(psi))
  end
  params.lastentropy = copy(params.entropy)

  mover(dualpsi,psi.oc)

  prevpsitype = typeof(psi[1])
  psiLenv = Array{prevpsitype,1}[Array{prevpsitype,1}(undef,Ns) for a = 1:length(prevpsi)]
  psiRenv = Array{prevpsitype,1}[Array{prevpsitype,1}(undef,Ns) for a = 1:length(prevpsi)]
  if length(prevpsi) > 0
    for b = 1:length(beta)
      mover(prevpsi[b],psi.oc)
      x,y = makePsiEnv(dualpsi,prevpsi[b])
      for w = 1:prevpsi[b].oc
        psiLenv[b][w] = x[w]
      end
      for w = Ns:-1:prevpsi[b].oc
        psiRenv[b][w] = y[w]
      end
    end
  end

  if typeof(psi) <: largeMPS || typeof(mpo) <: largeMPO
    params.psiLenv = Array{largeEnv,1}(undef,length(psiLenv))
    params.psiRenv = Array{largeEnv,1}(undef,length(psiRenv))
    for w = 1:length(psiLenv)
      thisLtag = "psiLenv$w"
      thisRtag = "psiRenv$w"
      params.psiLenv[w],params.psiRenv[w] = largeenvironment(psiLenv[w],psiRenv[w],Ltag=thisLtag,Rtag=thisRtag)
    end
  else
    params.psiLenv = environment(psiLenv)
    params.psiRenv = environment(psiRenv)
  end

  return params.Lenv,params.Renv,params.psiLenv,params.psiRenv,Nsteps,j
end


function Cpsipsi(AA::TensType,Lenv::TensType,Renv::TensType)
  LHpsi = contract(Lenv,2,AA,1)
  return contract(LHpsi,3,Renv,1)
end

function randLexpand(A::densTensType,expalpha::Float64,maxdim::Int64;bonddimfrac::Integer=5,mindim::Integer=10)
  checkmaxdim = max(maxdim-size(A,3),size(A,3))
  expAA = expalpha * rand(size(A,1),size(A,2),min(max(cld(size(A,3),bonddimfrac),mindim),checkmaxdim))
  return growindex(A,expAA,3)
end

function randRexpand(A::densTensType,expalpha::Float64,maxdim::Int64;bonddimfrac::Integer=5,mindim::Integer=10)
  checkmaxdim = max(maxdim-size(A,1),size(A,1))
  expAA = expalpha * rand(min(max(cld(size(A,1),bonddimfrac),mindim),checkmaxdim),size(A,2),size(A,3))
  return growindex(A,expAA,1)
end


function randLexpand(A::qarray,alpha::Float64,maxdim::Int64;bonddimfrac::Integer=5,mindim::Integer=10)#ops::W,HL::X,alpha::Float64)::qarray where {W <: qarray,X <: qarray,Y <: qarray}
  #never expand A beyond the specified maxdim
  #does nothing if A is already at its' maximum size.
  mindim = min(mindim,size(A,3))
  QnumL = [ A.flux + inv(q1) + inv(q2) for q1 in A.QnumMat[1] for q2 in A.QnumMat[2]]
  # minQnumL = unique(QnumL)
  checkmaxdim = max(maxdim-size(A,3),size(A,3))
  dim = min(max(cld(size(A,3),bonddimfrac),mindim),checkmaxdim,length(QnumL))
  newQ = [QnumL[rand(1:length(QnumL),1)...] for a = 1:dim] #Random.shuffle(QnumL)[1:dim]
  # newQ = [minQnumL[1:min(dim,length(minQnumL))]...,  Random.shuffle(QnumL)[1:dim-length(minQnumL)]...]
  #         ^to ensure some reprenstation of every possible qnums
  if length(newQ) > 0
    Qlabels = [A.QnumMat[1:2]...,newQ]
    addsize = length(newQ)
    Hpsi = rand(Qlabels)#,flux = A.flux) ## What happens if A is a complex tensor?
    A = growindex(A,Hpsi,3)
  end
  return A
end

function randRexpand(B::qarray,alpha::Float64,maxdim::Int64;bonddimfrac::Integer=5,mindim::Integer=10)::qarray
  #never expand B beyond the specified maxdim
  #does nothing if B is already at its' maximum size.
  mindim = min(mindim,size(B,1))
  QnumL = [ B.flux + inv(q1) + inv(q2) for q1 in B.QnumMat[2] for q2 in B.QnumMat[3]]
  # minQnumL = unique(QnumL)
  checkmaxdim = max(maxdim-size(B,3),size(B,3))
  dim = min(max(cld(size(B,1),bonddimfrac),mindim),checkmaxdim,length(QnumL))
  newQ = [QnumL[rand(1:length(QnumL),1)...] for a = 1:dim] #Random.shuffle(QnumL)[1:dim]
  # newQ = [minQnumL[1:min(dim,length(minQnumL))]...,  Random.shuffle(QnumL)[1:dim-length(minQnumL)]...]
  if length(newQ) > 0
    Qlabels = [newQ,B.QnumMat[2:3]...]
    Hpsi = rand(Qlabels)
    B = growindex(B,Hpsi,1)
  end
  return B
end

function NsiteOps(mpo::MPO,nsites::Integer)
  if nsites == 1
    out_mpo = mpo
  else
    if typeof(mpo[1]) <: qarray
      mpoType =  qarray
    elseif typeof(mpo[1]) <: denstens
      mpoType = denstens
    else
      mpoType = Array{eltype(mpo[1]),6}
    end
    nbonds = length(mpo)-nsites+1
    ops = Array{mpoType,1}(undef,nbonds)
    neworder = vcat([i for i = 1:2:2*nsites+1],[2*nsites+2],[i for i = 2:2:2*nsites])
    for i = 1:nbonds
      ops[i] = mpo[i]
      for b = 2:nsites
        ops[i] = contract(ops[i],ndims(ops[i]),mpo[i+b-1],1)
      end
      ops[i] = permutedims(ops[i],neworder)
    end
    out_mpo = MPO(ops)
  end
  return out_mpo
end

function singlesite_update(Lenv::TensType,Renv::TensType,AA::TensType,ops::TensType)
  LAA = contract(Lenv,(3,),AA,(1,))
  LopsAA = contract(LAA,(2,3),ops,(1,2))
  return contract(LopsAA,(2,4),Renv,(1,2))
#  Hpsi = contract(ops,[2],AA,[2])
#  LHpsi = contract(Lenv,[2,3],Hpsi,[1,4])
#  return contract(LHpsi,[4,3],Renv,[1,2])
end
export singlesite_update

function algvars(Q::DataType) #where Qn <: Qnum
  algvars{Float64,Q}(true, #load (loads variables from optional arguments or not)
                      "", #method
                      "", #parallel_method
                      1, #nsites
                      2, #minm
                      0, #maxm
                      0., #cutoff
                      0, #sweeps
                      false, #halfsweep
                      2, #maxiter
                      2, #mincr
                      true, #cvgE
                      0., #goal
                      1., #startnoise
                      1., #noise
                      0.3, #noise_goal
                      0.9, #noise_decay
                      0.01, #noise_incr
                      1, #exnum
                      0, #cushion
                      false, #shift
                      false, #fixD

                      1, #startoc
                      true, #origj
                      8, #maxshowD
                      [0. for i = 1:8], #storeD
                      [0.], #saveEnergy

                      0., #energy
                      0., #lastenergy

                      0., #entropy
                      0., #lastentropy

                      0., #truncerr
                      0., #maxtrunc #saves maximum truncation error
                      0, #biggestm
                      0, #savebiggestm
                      1, #SvNbond
                      false, #allSvNbond
                      [0], #Lbound
                      [0], #Rbound
                      [0], #Lenv
                      [0], #Renv

                      [[0]], #psiLenv
                      [[0]], #psiRenv

                      [0],#spare matrix
                      Q[],#saveQ

                      false, #efficient
                      false, #silent
                      Tuple{intType,Q}[], #qselect
                      Threads.nthreads() #partitions
                      )
end

function algvars()
  return algvars(U1)
end

function algvars(G::W) where W <: Union{MPS,MPO}
  if typeof(G[1]) <: densTensType
    out = algvars()
  else
    out = algvars(typeof(G[1].flux))
  end
  out.SvNbond = cld(length(G),2)
  return out
end

function Nstep(n::Integer,j::Integer,i::Integer,iL::Integer,iR::Integer,dualpsi::MPS,psi::MPS,mpo::MPO,
                  Lenv::Env,Renv::Env,psiLenv::Env,psiRenv::Env,beta::Array{Y,1},prevpsi::MPS...;
                  params::TNparams=params()) where Y <: Number

  vecTens = [psi[a] for a = iL:iR]
  AA = vecTens[1]
  for a = 2:length(vecTens)
    AA = contract(AA,ndims(AA),vecTens[a],1)
  end

  maxm = params.maxm
  minm = params.minm
  cutoff = params.cutoff

  D = AA + rand(AA)
  D /= norm(D)
  
  truncerr = 0.
  if j > 0
    for w = iR:-1:iL+1
      U,D,psi[w],truncerr = svd(D,[[i for i = 1:ndims(D)-2],[ndims(D)-1,ndims(D)]],m=maxm,minm=minm,cutoff=cutoff)#,mag=1.)
      if w == iL+1
        psi[iL] = U
        psi[iL+1] = contract(D,2,vecTens[2],1)
      else
        D = contract(U,ndims(U),D,1)
      end
    end
  else
    for w = iL:iR-1
      psi[w],D,V,truncerr = svd(D,[[1,2],[i for i = 3:ndims(D)]],m=maxm,minm=minm,cutoff=cutoff)#,mag=1.)
      if w == iR-1
        psi[iR-1] = contract(vecTens[end-1],3,D,1)
        psi[iR] = V
      else
        D = contract(D,2,V,1)
      end
    end
  end
  nothing
end

function loadvars!(params::TNparams,method::String,minm::Integer,maxm::Integer,sweeps::Integer,cutoff::Float64,silent::Bool,goal::Float64,
                  SvNbond::Integer,allSvNbond::Bool,efficient::Bool,cvgE::Bool,maxiter::Integer,fixD::Bool,nsites::Integer,
                  noise::Union{Float64,Array{Float64,1}},noise_decay::Float64,noise_goal::Float64,noise_incr::Float64,saveEnergy::W,halfsweep::Bool,Lbound::TensType,Rbound::TensType,
                  Lenv::Env,Renv::Env,psioc::Integer,origj::Bool,maxshowD::Integer,storeD::Array{Float64,1},exnum::Integer) where W <: Union{R,Array{R,1}} where R <: Number

  if params.load
    params.method = method
    params.minm = minm
    params.maxm = maxm
    params.sweeps = sweeps
    params.cutoff = cutoff
    params.silent = silent
    params.goal = goal
    params.SvNbond = SvNbond
    params.allSvNbond = allSvNbond
    params.efficient = efficient
    params.cvgE = cvgE
    params.maxiter = maxiter
    params.exnum = exnum
    params.fixD = fixD
    params.nsites = nsites
    params.startnoise = noise
    params.noise = noise
    params.noise_decay = noise_decay
    params.noise_goal = noise_goal
    params.noise_incr = noise_incr
    params.saveEnergy = saveEnergy
    params.halfsweep = halfsweep
    params.Lbound = Lbound
    params.Rbound = Rbound
    params.Lenv = Lenv
    params.Renv = Renv
    params.startoc = psioc
    params.origj = origj
    params.maxshowD = maxshowD
    params.storeD = storeD
  end
  nothing
end
export loadvars!

"""
infovals: stores current energy (skips initialization for it), truncation error, 
                        entanglement entropy on requested bond (default center), 
                        largest m value, noise parameter  <---switch to second slot
"""
function optimize(dualpsi::MPS,psi::MPS,mpo::MPO,beta::Array{P,1},prevpsi::MPS...;params::TNparams=algvars(),
                  method::String="optimize",maxm::Integer=0,minm::Integer=2,sweeps::Integer=1,
                  cutoff::Float64=0.,silent::Bool=false,goal::Float64=0.,infovals::Array{Float64,1}=zeros(5),
                  SvNbond::Integer=fld(length(psi),2),allSvNbond::Bool=false,efficient::Bool=false,
                  cvgE::Bool=true,maxiter::Integer=2,exnum::Integer=1,fixD::Bool=false,nsites::Integer=1,
                  noise::Number=1.0,noise_decay::Float64=0.9,noise_goal::Float64=0.3,noise_incr::Float64=0.01,
                  saveEnergy::Array{R,1}=[0],halfsweep::Bool=false,Lbound::TensType=[0],Rbound::TensType=[0],
                  Lenv::Env=[0],Renv::Env=[0],origj::Bool=true,maxshowD::Integer=8,
                  storeD::Array{W,1}=[0.]) where {W <: Number, R <: Number,P <: Number}
  loadvars!(params,method,minm,maxm,sweeps,cutoff,silent,goal,SvNbond,allSvNbond,efficient,cvgE,maxiter,fixD,nsites,
            noise,noise_decay,noise_goal,noise_incr,saveEnergy,halfsweep,Lbound,Rbound,Lenv,Renv,psi.oc,origj,maxshowD,storeD,exnum)
  return optmps(dualpsi,psi,mpo,beta,prevpsi...,params=params)
end
export optimize




function Noptimize(dualpsi::MPS,psi::MPS,mpo::MPO,beta::Array{P,1},prevpsi::MPS...;
                  method::String="optimize",maxm::Integer=0,minm::Integer=2,sweeps::Integer=1,
                  cutoff::Float64=0.,silent::Bool=false,goal::Float64=0.,infovals::Array{Float64,1}=zeros(5),
                  SvNbond::Integer=fld(length(psi),2),allSvNbond::Bool=false,efficient::Bool=false,
                  cvgE::Bool=true,maxiter::Integer=2,exnum::Integer=1,fixD::Bool=false,nsites::Integer=2,
                  noise::Number=1.0,noise_decay::Float64=0.9,noise_goal::Float64=0.3,noise_incr::Float64=0.01,
                  saveEnergy::Array{R,1}=[0],halfsweep::Bool=false,Lbound::TensType=[0],Rbound::TensType=[0],
                  Lenv::Env=[0],Renv::Env=[0],origj::Bool=true,maxshowD::Integer=8,
                  storeD::Array{W,1}=[0.]) where {W <: Number,R <: Number,P <: Number}
  loadvars!(params,method,minm,maxm,sweeps,cutoff,silent,goal,SvNbond,allSvNbond,efficient,cvgE,maxiter,fixD,nsites,
            noise,noise_decay,noise_goal,noise_incr,saveEnergy,halfsweep,Lbound,Rbound,Lenv,Renv,psi.oc,origj,maxshowD,storeD,exnum)
  return optmps(dualpsi,psi,mpo,beta,prevpsi...,params=params,stepfct=Nstep,#=makeOps=NsiteOps,=#cvgfct=nullcvg)
end
export Noptimize





function optmps(dualpsi::MPS,psi::MPS,mpo::MPO,beta::Array{P,1},prevpsi::MPS...;params::TNparams=algvars(),
                  displayfct::Function=optinformation,Envfct::Function=setEnv,
                  measfct::Function=expect,stepfct::Function=optstep,
#                  makeOps::Function=NsiteOps,
                  cvgfct::Function=optcvg,
                  mover::Function=move!,boundarymover::Function=boundaryMove!,
                  builtEnvBool::Bool=true) where P <: Number

  if !params.silent && !params.efficient
    displayfct(params)
  end

  out = Envfct(dualpsi,psi,mpo,params,prevpsi...,measfct=measfct,mover=mover)
  params.Lenv,params.Renv,params.psiLenv,params.psiRenv,#=SvN,lastSvN,m,maxtrunc,biggestm,Ns,=#Nsteps,#=timer,=#j#=,SvNvec,startoc=# = out

  #make operators...or identity
#  ops = makeOps(mpo,params.nsites)
  
  range = max(2,params.nsites)-1

  Ns = length(psi)
  timer = 0.

  totsweeps = params.halfsweep ? params.sweeps+1 : params.sweeps
#=    if length(psi) == 1
    for n = 1:totsweeps
      AAvec,outEnergy = krylov(singlesite_update,psi[1],mpo[1],Lenv[1],Renv[1],maxiter=maxiter)
      psi[1] = AAvec[1]
      params.energy = outEnergy[1]
    end
  else=#
    for n = 1:totsweeps
      if !params.silent
        timer = -time()
      end

      for ns in 1:Nsteps
        i = psi.oc
        
        if j > 0
          iL,iR = i,i+range
        else
          iL,iR = i-range,i
        end

        #D,truncerr = 
        stepfct(n,j,i,iL,iR,dualpsi,psi,mpo,params.Lenv,params.Renv,
                params.psiLenv,params.psiRenv,beta,prevpsi...,params=params)

        if builtEnvBool
          if j > 0
            params.Lenv[i+1] = Lupdate(params.Lenv[i],dualpsi[i],psi[i],mpo[i])
            for b = 1:length(prevpsi)
              params.psiLenv[b][i+1] = Lupdate(params.psiLenv[b][i],dualpsi[i],prevpsi[b][i])
            end
          else
            params.Renv[i-1] = Rupdate(params.Renv[i],dualpsi[i],psi[i],mpo[i])
            for b = 1:length(prevpsi)
              params.psiRenv[b][i-1] = Rupdate(params.psiRenv[b][i],dualpsi[i],prevpsi[b][i])
            end
          end
          #update oc's position
          psi.oc += j
        end

        ##reverse direction if we hit the edge
        if psi.oc == Ns - (range-1) && j > 0
          boundarymover(psi,Ns,params.Lenv,params.Renv,mpo)
          j *= -1
        elseif psi.oc == 1 + (range-1) && j < 0
          boundarymover(psi,1,params.Lenv,params.Renv,mpo)
          j *= -1
        end
        for b = 1:length(prevpsi)
          boundarymover(prevpsi[b],psi.oc,params.psiLenv[b],params.psiRenv[b])
        end
      end
      if !params.silent
        timer += time()
      end
      if !params.efficient
        breakbool = cvgfct(n,timer,dualpsi,psi,mpo,
                            params.Lenv,params.Renv,
                            params.psiLenv,params.psiRenv,beta,
                            prevpsi...,params=params)
        
        if breakbool
          break
        end
      end
    end
#    end

  return params.energy
end
export optmps

function makePsiEnv(dualpsi::MPS,psi::MPS)
  Ns = size(psi,1)
  if typeof(psi[1]) <: qarray
    thistype = qarray
  elseif typeof(psi[1]) <: denstens
    thistype = denstens
  elseif typeof(psi[1]) <: AbstractArray
    thistype = AbstractArray
  end
  Lenv = Array{thistype,1}(undef,Ns)
  Renv = Array{thistype,1}(undef,Ns)
  Lenv[1],Renv[end] = makeEnds(dualpsi,psi)
  for i = 1:dualpsi.oc-1
    Lenv[i+1] = Lupdate(Lenv[i],dualpsi[i],psi[i])
  end
  for i = Ns:-1:dualpsi.oc+1
    Renv[i-1] = Rupdate(Renv[i],dualpsi[i],psi[i])
  end
  return Lenv,Renv
end

function Hpsi(psi::MPS,a::Integer,mpo::MPO,Lenv::Env,Renv::Env,
              psiLenv::Env,psiRenv::Env,beta::Array{W,1},
              prevpsi::MPS...) where W <: Number
  AAvec = singlesite_update(Lenv[a],Renv[a],psi[a],mpo[a])
  for b = 1:length(prevpsi)
    lpsi = Cpsipsi(prevpsi[b][a],psiLenv[b][a],psiRenv[b][a])
    AAvec = sub!(AAvec,lpsi,beta[b])
  end
  normAAvec = norm(AAvec)
  if normAAvec == 0
    AAvec = copy(psi[a])
    println("BIG WARNING")
  else
    AAvec = div!(AAvec,normAAvec)
  end
  return AAvec
end

function optstep(n::Integer,j::Integer,i::Integer,iL::Integer,iR::Integer,dualpsi::MPS,psi::MPS,mpo::MPO,
                  Lenv::Env,Renv::Env,psiLenv::Env,psiRenv::Env,beta::Array{Y,1},prevpsi::MPS...;params::TNparams=params(),applyHpsi::Function=Hpsi,
                  Lmover::Function=moveL,Rmover::Function=moveR,Lexpander::Function=randLexpand,Rexpander::Function=randRexpand) where Y <: Number
  AAvec = applyHpsi(psi,i,mpo,Lenv,Renv,psiLenv,psiRenv,beta,prevpsi...)
  dualpsi[i] = AAvec
  expalpha = params.noise
  exp_condition = expalpha > 0.

  maxm = params.maxm
  minm = params.minm
  cutoff = params.cutoff

  if exp_condition
    if j > 0
      dualpsi[i] = Lexpander(AAvec,expalpha,maxm)
    else
      dualpsi[i] = Rexpander(AAvec,expalpha,maxm)
    end
  else
    dualpsi[i] = AAvec
  end
  if j > 0
    dualpsi[iL],dualpsi[iR],D,truncerr = Rmover(dualpsi[iL],dualpsi[iR],cutoff=cutoff,m=maxm,minm=minm,condition=exp_condition)
  else
    dualpsi[iL],dualpsi[iR],D,truncerr = Lmover(dualpsi[iL],dualpsi[iR],cutoff=cutoff,m=maxm,minm=minm,condition=exp_condition)
  end

  dualpsi.oc += j

  return D,truncerr
end
export optstep

function nullcvg(n::Integer,timer::Number,dualpsi::MPS,psi::MPS,mpo::MPO,Lenv::Env,Renv::Env,psiLenv::Env,psiRenv::Env,beta::Array{W,1},prevpsi::MPS...;
                  params::TNparams=params())::Bool where W <: Number
  println("sweep $n, time = $timer")
  return false
end

function optcvg(n::Integer,timer::Number,dualpsi::MPS,psi::MPS,mpo::MPO,Lenv::Env,Renv::Env,psiLenv::Env,psiRenv::Env,beta::Array{W,1},prevpsi::MPS...;
                  params::TNparams=params())::Bool where W <: Number

  i = dualpsi.oc
  tmp = singlesite_update(Lenv[i],Renv[i],psi[i],mpo[i])
  overlap = ccontract(tmp,dualpsi[i])
  for b = 1:length(prevpsi)
    tmp = Cpsipsi(prevpsi[b][i],psiLenv[b][i],psiRenv[b][i])
    overlap -= beta[b]^2 * ccontract(tmp,dualpsi[i])
  end
  normpsi = ccontract(dualpsi[i])

  Error_val = (params.goal + real(normpsi) - 2*real(overlap))/real(normpsi)

#    for a in dualpsi.A
#      print(size(a))
#    end
  println("Error at sweep $n: $Error_val")

  m = maximum([size(dualpsi[a],3) for a = 1:size(dualpsi,1)])
  if (m < params.maxm || true) && n%3 == 0
    params.noise = params.startnoise
  else
    params.noise = 0.
  end

  return false
end
#end
