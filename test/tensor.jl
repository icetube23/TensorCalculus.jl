@testset "Properties" begin
    # the expected base methods for arrays also work on tensors
    t1 = Tensor(rand(3, 3))
    @test size(t1) == (3, 3)
    @test size(t1, 1) == 3
    @test ndims(t1) == 2
    @test length(t1) == 9
    @test eltype(t1) === Float64

    t2 = Tensor(rand(Int32, 3, 3, 3))
    @test size(t2) == (3, 3, 3)
    @test size(t2, 2) == 3
    @test ndims(t2) == 3
    @test length(t2) == 27
    @test eltype(t2) === Int32

    t3 = Tensor(3.0f0)
    @test size(t3) == ()
    @test size(t3, 3) == 1
    @test ndims(t3) == 0
    @test length(t3) == 1
    @test eltype(t3) === Float32
end

@testset "Equality" begin
    a1 = rand(2, 3, 3)
    t1 = Tensor(a1)

    # t1 and t2 share their underlying data, thus t1 === t2
    a2 = a1
    t2 = Tensor(a2)
    @test t1 === t2
    @test t1 == t2
    @test t1 ≈ t2

    # t1 and t2 don't share their data, but contain the same values
    a2 = copy(a1)
    t2 = Tensor(a2)
    @test t1 !== t2
    @test t1 == t2
    @test t1 ≈ t2

    # t1 and t2 differ very slightly in one value
    a2[1, 2, 3] += 1e-10
    t2 = Tensor(a2)
    @test t1 !== t2
    @test t1 != t2
    @test t1 ≈ t2

    # t1 and t2 differ in one value
    a2[1, 2, 3] = 4
    t2 = Tensor(a2)
    @test t1 !== t2
    @test t1 != t2
    @test !(t1 ≈ t2)
end

@testset "Types" begin
    # rand puts out Float64 per default
    t1 = Tensor(rand(3, 3))
    @test eltype(t1) === Float64

    t2 = Tensor{Float32}(t1)
    @test eltype(t2) === Float32

    t3 = convert(Tensor{Float16}, t1)
    @test eltype(t3) === Float16

    # like Base.convert throws an error when performing inexact conversions
    @test_throws InexactError Tensor{Int64}(t1)
    @test_throws InexactError convert(Tensor{Int64}, t1)

    # scalar tensors can be converted to the underlying scalar
    t4 = Tensor(4)
    @test convert(Int64, t4) == 4
    @test Int64(t4) == 4

    # not possible for non-scalar tensors
    @test_throws MethodError convert(Float64, t1)
    @test_throws MethodError Float64(t1)
end

@testset "Reshaping" begin
    t1 = Tensor(Vector(1:9))
    @test size(t1) == (9,)

    # reshaping does not alter the original tensor
    t2 = reshape(t1, 3, 3)
    @test size(t1) == (9,)
    @test size(t2) == (3, 3)
    @test t2 == Tensor([
        1 4 7
        2 5 8
        3 6 9
    ])

    # permutedims also does not alter the original tensor
    t3 = Tensor(rand(5, 4, 2))
    @test size(t3) == (5, 4, 2)
    t4 = permutedims(t3, (3, 1, 2))
    @test size(t3) == (5, 4, 2)
    @test size(t4) == (2, 5, 4)

    @test t3 != t4
    @test t3[:, :, 1] == t4[1, :, :]
    @test t3[:, :, 2] == t4[2, :, :]

    # on 1- and 2-dimensional tensors the permutation tuple can be omitted
    @test permutedims(Tensor([1, 2, 3])) == Tensor([1 2 3])
    @test permutedims(Tensor([1 2 3])) == Tensor(reshape([1, 2, 3], 3, 1))
    @test permutedims(Tensor([1 2 3; 4 5 6])) == Tensor([1 4; 2 5; 3 6])
end

@testset "Indexing" begin
    # indexing a tensor works like indexing the wrapped array
    t = Tensor(rand(1, 2, 3, 3))
    @test axes(t) == (Base.OneTo(1), Base.OneTo(2), Base.OneTo(3), Base.OneTo(3))
    @test eachindex(t) == Base.OneTo(18)
    @test CartesianIndices(t) == CartesianIndices(axes(t))

    t1 = t[1, :, :, :]
    @test t1 isa Tensor{Float64,3}
    @test size(t1) == (2, 3, 3)
    @test t1 == t[1, :, :, :]

    t2 = t[:, 2, :, 3]
    @test t2 isa Tensor{Float64,2}
    @test size(t2) == (1, 3)
    @test t2 == t[:, 2, :, 3]

    t3 = t[1, 2, 3, 2]
    @test t3 isa Tensor{Float64,0}
    @test size(t3) == ()
    @test t3 == t[1, 2, 3, 2]
    @test_throws BoundsError t3[1]

    t[1, 1, 1, :] = Tensor([1, 2, 3])
    @test t[1, 1, 1, :] == Tensor([1.0, 2.0, 3.0])

    # tensor elements can be assigned scalars and scalar tensors
    t[1, 1, 1, 2] = 4
    t[1, 1, 1, 3] = Tensor(9)
    @test t[1, 1, 1, :] == Tensor([1.0, 4.0, 9.0])

    # throws BoundsError if indices are out-of-range
    @test_throws BoundsError t[2, :, :, :]
    @test_throws BoundsError t[1, 3, 3, 3] = 2

    # checkbounds can also be used directly
    @test checkbounds(Bool, t, 1, 1, 1, 1)
    @test !checkbounds(Bool, t, 2, 1, 1, 1)
    @test_throws BoundsError checkbounds(t, 2, 1, 1, 1)
end

@testset "Printing" begin
    # test that tensors show methods work upon array show methods
    io = IOBuffer()
    # NOTE: for compatibility with Julia 1.0 which used slightly different; remove if
    # compatibility with this version is no longer needed/supported
    norm(s) = filter(x -> x != ' ', s)

    t1 = Tensor(2)
    show(io, t1)
    @test norm(String(take!(io))) == norm("Tensor{Int64, 0}(2)")
    show(io, "text/plain", t1)
    @test norm(String(take!(io))) == norm(join(
        [
            "scalar Tensor{Int64, 0}:"
            "2"
        ],
        "\n",
    ))

    t2 = Tensor(Vector{Float64}(1:4))
    show(io, t2)
    @test norm(String(take!(io))) == norm("Tensor{Float64, 1}($(t2.data))")
    show(io, "text/plain", t2)
    @test norm(String(take!(io))) == norm(join(
        [
            "4-element Tensor{Float64, 1}:"
            " 1.0"
            " 2.0"
            " 3.0"
            " 4.0"
        ],
        "\n",
    ))

    t3 = Tensor(reshape(Vector{Int32}(1:9), 3, 3))
    show(io, t3)
    @test norm(String(take!(io))) == norm("Tensor{Int32, 2}($(t3.data))")
    show(io, "text/plain", t3)
    @test norm(String(take!(io))) == norm(join(
        [
            "3×3 Tensor{Int32, 2}:"
            " 1  4  7"
            " 2  5  8"
            " 3  6  9"
        ],
        "\n",
    ))

    t4 = Tensor(reshape(Vector{Float32}(1:8), 2, 2, 2))
    show(io, t4)
    @test norm(String(take!(io))) == norm("Tensor{Float32, 3}($(t4.data))")
    show(io, "text/plain", t4)
    @test norm(String(take!(io))) == norm(
        join(
            [
                "2×2×2 Tensor{Float32, 3}:"
                "[:, :, 1] ="
                " 1.0  3.0"
                " 2.0  4.0"
                ""
                "[:, :, 2] ="
                " 5.0  7.0"
                " 6.0  8.0"
            ],
            "\n",
        ),
    )
end

@testset "Hashing" begin
    t = Tensor(rand(3, 3))

    # tensors are hashable and their hash is different than the hash of the underlying data
    @test hash(t) != hash(t.data)
    @test hash(t) == hash(hash(t.data) + hash("t"))

    # tensors can be used in a dict
    d = Dict(t => (3, 3))
    @test d[t] == (3, 3)
end

@testset "Delta" begin
    # the delta tensor is a square boolean tensor of dimension 2
    d3 = δ(3)
    @test size(d3) == (3, 3)
    @test eltype(d3) === Bool

    # the delta tensor acts like the neutral element of the inner product
    t = Tensor(rand(3, 4, 5))
    @test t ⋅ δ(5) == δ(3) ⋅ t == t
    @test δ(4) ⋅ δ(4) == δ(4)

    # delta tensor can also be created using a value type
    @test δ(Val(4)) == δ(4)
end

@testset "Epsilon" begin
    # the nth epsilon tensor is an n×...×n Int8 tensor of dimension n
    eps3 = ϵ(3)
    @test size(eps3) == (3, 3, 3)
    @test eltype(eps3) === Int8

    # the epsilon tensor can be used to generalize the cross product to tensors
    t1 = Tensor([1, 0, 0])
    t2 = Tensor([0, 1, 0])
    # TODO: adjust cross product definition if actual implementation changes
    @test -(t1 ⋅ ϵ(3) ⋅ t2) == Tensor([0, 0, 1]) # = t1 × t2

    # it also generalizes the tensors of higher dimensions than 1
    t3 = Tensor([
        1 0 0
        2 0 0
    ])
    @test -(t3 ⋅ ϵ(3) ⋅ t2) == Tensor([
        0 0 1
        0 0 2
    ])

    # it can also work on dimensions different than 3 with a little creativity
    t4 = Tensor([1, 0, 0, 0])
    t5 = Tensor([0, 1, 0, 0])
    t6 = Tensor([0, 0, 1, 0])
    @test ϵ(4) ⋅ t4 ⋅ t5 ⋅ t6 == Tensor([0, 0, 0, 1])
end
