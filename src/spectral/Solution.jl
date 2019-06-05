export SolutionInv

# Solution wrappers
@compat struct SolutionInvWrapper{QR<:ApproxFunBase.QROperator,F<:Fun,T} <: Operator{T}
  op::QR
  u::F
end
SolutionInvWrapper(op::ApproxFunBase.QROperator,f::Fun) = SolutionInvWrapper{typeof(op),typeof(f),eltype(op)}(op,f)
ApproxFun.qr!(op::SolutionInvWrapper) = op
ApproxFun.qr(op::SolutionInvWrapper) = op
#SolutionInvWrapper(op::Operator) = SolutionInvWrapper(op,uniform(domainspace(op)))
ApproxFun.@wrapper SolutionInvWrapper

#ApproxFun.\{S,T,DD,dim}(A::SolutionInvWrapper,b::Fun{MatrixSpace{S,T,DD,dim}};kwds...) = \(L.op,b;kwds...) # avoid method ambiguity
(\)(L::SolutionInvWrapper,b::ApproxFun.Fun;kwds...) = \(L.op,b;kwds...)

function uniform(S::Space)
  u = Fun(one,S)
  @compat rmul!(u.coefficients,1/sum(u))
  u
end
uniform(D::Domain) = uniform(Space(D))

function SolutionInv(L::Operator,u::Fun=uniform(domainspace(L)))
  @assert domain(L) == rangedomain(L)
  if isa(domainspace(L),ApproxFun.TensorSpace) #TODO: put this into ApproxFun
    di = DefiniteIntegral(domainspace(L).spaces[1])⊗DefiniteIntegral(domainspace(L).spaces[2])
    for i = 3:length(domainspace(L).spaces)
      di = di⊗DefiniteIntegral(domainspace(L).spaces[2])
    end
  else
    di = DefiniteIntegral(domainspace(L))
  end


  SolutionInvWrapper(ApproxFun.qr(I-L + cache(u/sum(u) * di)),u)
end
SolutionInv(M::AbstractMarkovMap,u::Fun=uniform(Space(domain(M)))) = SolutionInv(Transfer(M,space(u)),u)

Transfer(K::SolutionInvWrapper) = K.op.R_cache.op.ops[2].op # eek??



# function DefiniteIntegral(sp::ProductSpace) # likely a hack
#   di = DefiniteIntegral(sp.spaces[1])
#   for i = 2:length(sp.spaces)
#     di = di⊗DefiniteIntegral(sp.spaces[i])
#   end
#   di
# end
