#########################################################################
#
#  Density Matrix Renormalization Group (and other methods) in julia (DMRjulia)
#                              v0.8.3
#
#########################################################################
# Made by Thomas E. Baker (2018)
# See accompanying license with this program
# This code is native to the julia programming language (v1.1.1) or (v1.5)
#


path = "../src/"
include(path*"DMRjulia.jl")
using .DMRJtensor


Ns = 10

@makeQNs "fermion" U1 U1
Qlabels = [[fermion(0,0),fermion(1,1),fermion(1,-1),fermion(2,0)]]

Ne = Ns
Ne_up = ceil(Int64,div(Ne,2))
Ne_dn = Ne-Ne_up
QS = 4
Cup,Cdn,F,Nup,Ndn,Ndens,O,Id = fermionOps()

psi = MPS(QS,Ns)
upsites = [i for i = 1:Ne_up]
Cupdag = Matrix(Cup')
applyOps!(psi,upsites,Cupdag,trail=F)


dnsites = [i for i = 1:Ne_dn]
Cdndag = Matrix(Cdn')
applyOps!(psi,dnsites,Cdndag,trail=F)

qpsi = makeqMPS(Qlabels,psi)

mu = -2.0
HubU = 4.0
t = 1.0

function H(i::Int64)
        onsite = mu * Ndens + HubU * Nup * Ndn #- Ne*exp(-abs(i-Ns/2)/2)*Ndens
        return [Id  O O O O O;
            -t*Cup' O O O O O;
            conj(t)*Cup  O O O O O;
            -t*Cdn' O O O O O;
            conj(t)*Cdn  O O O O O;
            onsite Cup*F Cup'*F Cdn*F Cdn'*F Id]
    end

println("Making qMPO")

@time mpo = makeMPO(H,QS,Ns)
@time qmpo = makeqMPO(Qlabels,mpo)


println("#############")
println("QN version")
println("#############")

QNenergy = dmrg(qpsi,qmpo,m=45,sweeps=20,cutoff=1E-9)


println("#############")
println("nonQN version")
println("#############")

energy = dmrg(psi,mpo,m=45,sweeps=20,cutoff=1E-9)

println(QNenergy-energy)


qNup,qNdn = Qtens([Qlabels[1],inv.(Qlabels[1])],Nup,Ndn)

for i = 1:length(qpsi)
    move!(qpsi,i)
    println(i," ",ccontract(qpsi[i],contract([2,1,3],qNup,2,qpsi[i],2)))
  end
  for i = 1:length(qpsi)
    move!(qpsi,i)
    println(i," ",ccontract(qpsi[i],contract([2,1,3],qNdn,2,qpsi[i],2)))
  end



  for i = 1:length(qpsi)
    move!(psi,i)
    println(i," ",ccontract(psi[i],contract([2,1,3],Nup,2,psi[i],2)))
  end
  for i = 1:length(psi)
    move!(psi,i)
    println(i," ",ccontract(psi[i],contract([2,1,3],Ndn,2,psi[i],2)))
  end
