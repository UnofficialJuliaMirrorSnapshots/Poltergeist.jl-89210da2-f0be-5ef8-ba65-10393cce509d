module HGraphs

using ApproxFun
using LightGraphs
import LightGraphs: has_vertex, add_vertex!, has_edge, #fedgelist, bedgelist,
    inneighbors, outneighbors, is_directed, add_edge!, rem_edge!,
    ne, nv, vertices, src, dst
import LightGraphs.SimpleGraphs, Poltergeist
import LightGraphs.SimpleGraphs: fadj, badj
import Poltergeist: AbstractIntervalMap
import Base: show
export HofbauerEdge, HofbauerExtension, hdomains, domains, isnfp, getmap
export fedge, bedge, branchind
# code modified from LightGraphs.jl

"""
    HofbauerEdge
A LightGraphs AbstractEdge object used as edges of a HofbauerExtension.
Annotated with a branch index and a bool value indicating whether the edge passes through a neutral fixed point.
"""
struct HofbauerEdge{I} <: LightGraphs.AbstractEdge{Int}
    src::Int
    dst::Int
    branchind::I
    isnfp::Bool
end
const HEdge{I} = HofbauerEdge{I} where I
show(io::IO,e::HEdge) = print(io,
    "Edge $(src(e)) >$(branchind(e))=> $(dst(e))"*# over branch $(branchind(e))" *
    (isnfp(e) ? " around neutral f.p." : ""))
src(e::HEdge) = e.src
dst(e::HEdge) = e.dst
branchind(e::HEdge) = e.branchind
branchindtype(e::HEdge{I} where I) = I
isnfp(e::HEdge) = e.isnfp
SimpleEdge(e::HEdge) = SimpleEdge{Int}(e.src,e.dst)

Base.isless(e::HEdge{I},f::HEdge{I}) where I =
    (e.src,e.branchind,e.dst,e.isnfp) < (f.src,f.branchind,f.dst,f.isnfp)

# for splicing
Base.length(::HEdge) = 1
Base.iterate(x::HEdge, state=false) = state ? nothing : (x, true)

### from SimpleGraphs/simpledigraph.jl

mutable struct HofbauerExtension{I,D,M<:Poltergeist.AbstractIntervalMap} <: AbstractGraph{Int}
    ne::Int
    fedgelist::Vector{Vector{HEdge{I}}}
    bedgelist::Vector{Vector{HEdge{I}}}
    m::M
    hdomains::Vector{D}
    returnto::Vector{Int}
end
show(io::IO, h::HofbauerExtension) = print(io,
    "Hofbauer extension of $(getmap(h)) of size {$(nv(h)), $(ne(h))}")

eltype(x::HofbauerExtension) = Int # for graph compatibiltiy
zero(h::HofbauerExtension{I}) where I = HofbauerExtension(0,Vector{HEdge{I}}[],Vector{HEdge{I}}[],h.m,h.hdomains,h.returnto)

HofbauerExtension{I,D}(m::AbstractIntervalMap) where {I,D} = HofbauerExtension(0, Vector{HEdge{I}}[], Vector{HEdge{I}}[],m,D[],Int[])
HofbauerExtension(m::AbstractIntervalMap) = HofbauerExtension{Int,Interval{Float64}}(m)
HofbauerExtension(::Type{T},::Type{D},m::AbstractIntervalMap) where {T,D} = HofbauerExtension{T,D}(m)

edgetype(::HofbauerExtension{T}) where T<: Integer = HEdge{T}
getmap(g::HofbauerExtension) = g.m

fedge(g::HofbauerExtension) = g.fedgelist
fedge(g::HofbauerExtension,v) = fedge(g)[v]
bedge(g::HofbauerExtension) = g.bedgelist
bedge(g::HofbauerExtension,v) = bedge(g)[v]
hdomains(g::HofbauerExtension) = g.hdomains
domains(g::HofbauerExtension) = Domain.(hdomains(g))

fadj(g::HofbauerExtension) =[sort(unique(dst.(be))) for be in g.fedgelist]
fadj(g::HofbauerExtension, v::Integer) = sort(unique(dst.(g.fedgelist[v])))
badj(g::HofbauerExtension) = [sort(unique(src.(be))) for be in g.bedgelist]
badj(g::HofbauerExtension, v::Integer) = sort(unique(src.(g.bedgelist[v])))

inneighbors(g::HofbauerExtension, v::Integer) = badj(g, v)
outneighbors(g::HofbauerExtension, v::Integer) = fadj(g, v)


==(g::HofbauerExtension, h::HofbauerExtension) =
    vertices(g) == vertices(h) &&
    ne(g) == ne(h) &&
    fedge(g) == fedge(h) &&
    bedge(g) == bedge(h) &&
    hdomains(g) == hdomains(h)

is_directed(g::HofbauerExtension) = true
is_directed(::Type{HofbauerExtension}) = true
is_directed(::Type{HofbauerExtension{I}}) where I = true
is_directed(::Type{HofbauerExtension{I,D}}) where I where D = true
is_directed(::Type{HofbauerExtension{I,D,M}}) where I where D where M = true

function SimpleDiGraph(g::HofbauerExtension)
    sg = SimpleDiGraph{Int}(nv(g))
    for el in fedge(g)
        for e in el
            add_edge!(sg,SimpleEdge(e))
        end
    end
    sg
end

_insert_and_dedup!(v::Vector{T}, x::T) where T <: HEdge =
    isempty(splice!(v, searchsorted(v, x), x))

function add_edge!(g::HofbauerExtension{I}, e::HEdge{I}) where I
     s = e.src; d = e.dst
    inserted = _insert_and_dedup!(g.fedgelist[s], e)
    if inserted
        g.ne += 1
    end
    return inserted && _insert_and_dedup!(g.bedgelist[d], e)
end


function rem_edge!(g::HofbauerExtension, e::HEdge)
    i = searchsorted(g.fedgelist[src(e)], e)
    isempty(i) && return false # edge doesn't exist
    j = first(i)
    deleteat!(g.fedgelist[src(e)], j)
    j = searchsortedfirst(g.bedgelist[dst(e)], e)
    deleteat!(g.bedgelist[dst(e)], j)
    g.ne -= 1
    return true
end


function add_vertex!(g::HofbauerExtension{I,D},d::D;forcereturn=true) where I where D
    (nv(g) + 1 <= nv(g)) && return false       # test for overflow
    push!(g.bedgelist, Vector{I}())
    push!(g.fedgelist, Vector{I}())
    push!(g.hdomains, d)
    forcereturn && push!(g.returnto,nv(g))
    return true
end


function has_edge(g::HofbauerExtension, e::HEdge)
    u, v = e.src, e.dst
    (u > nv(g) || v > nv(g)) && return false
    if degree(g, u) < degree(g, v)
        return insorted(v, fedge(g, u))
    else
        return insorted(u, bedge(g, v))
    end
end

### from SimpleGraphs/SimpleGraphs.jl

ne(g::HofbauerExtension) = g.ne
nv(g::HofbauerExtension) = length(fedge(g))
vertices(g::HofbauerExtension) = 1:nv(g)
end
using Poltergeist.HGraphs
