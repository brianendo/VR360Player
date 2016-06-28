//
//  Vertex.swift
//  VR360Player
//
//  Created by Brian Endo on 6/23/16.
//  Copyright © 2016 Brian Endo. All rights reserved.
//


import GLKit

typealias VertexPositionComponent = (GLfloat, GLfloat, GLfloat)
typealias VertexTextureCoordinateComponent = (GLfloat, GLfloat)

struct TextureVertex
{
    var position: VertexPositionComponent = (0, 0, 0)
    var texture: VertexTextureCoordinateComponent = (0, 0)
}
