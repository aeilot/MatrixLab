import SwiftUI
import SceneKit

// MARK: - QuadricSurfaceView

/// A SceneKit-based view that renders the quadric surface x^T A x = 1
/// for a given 3x3 symmetric matrix A.
struct QuadricSurfaceView: UIViewRepresentable {
    @ObservedObject var matrix: SymmetricMatrix3x3
    var accentColor: Color
    @Binding var resetCamera: Bool

    private static let defaultCameraPosition = SCNVector3(3, 2.5, 4)

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = UIColor(MatrixTheme.background)
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.scene = buildScene()
        context.coordinator.scnView = scnView
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        scnView.scene = buildScene()

        if resetCamera {
            // Reset to the default camera from the new scene
            if let cameraNode = scnView.scene?.rootNode.childNodes.first(where: { $0.camera != nil }) {
                scnView.pointOfView = cameraNode
            }
            DispatchQueue.main.async {
                resetCamera = false
            }
        }
    }

    class Coordinator {
        weak var scnView: SCNView?
    }

    // MARK: - Scene Construction

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(MatrixTheme.background)

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(3, 2.5, 4)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        // Lighting
        addLighting(to: scene)

        // Axes
        addAxes(to: scene)

        // Quadric surface
        if let surfaceNode = buildQuadricNode() {
            scene.rootNode.addChildNode(surfaceNode)
        }

        return scene
    }

    private func addLighting(to scene: SCNScene) {
        // Key light
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 800
        keyLight.light?.color = UIColor.white
        keyLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(keyLight)

        // Fill light
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 300
        fillLight.light?.color = UIColor(white: 0.8, alpha: 1)
        fillLight.eulerAngles = SCNVector3(Float.pi / 6, -Float.pi / 3, 0)
        scene.rootNode.addChildNode(fillLight)

        // Ambient
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 200
        ambient.light?.color = UIColor(white: 0.4, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    private func addAxes(to scene: SCNScene) {
        let axisLength: Float = 2.5
        let axisRadius: Float = 0.012

        // X axis (red)
        addAxisLine(to: scene, direction: SCNVector3(axisLength, 0, 0),
                    color: UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 0.6), radius: axisRadius)
        // Y axis (green)
        addAxisLine(to: scene, direction: SCNVector3(0, axisLength, 0),
                    color: UIColor(red: 0.3, green: 1, blue: 0.3, alpha: 0.6), radius: axisRadius)
        // Z axis (blue)
        addAxisLine(to: scene, direction: SCNVector3(0, 0, axisLength),
                    color: UIColor(red: 0.3, green: 0.5, blue: 1, alpha: 0.6), radius: axisRadius)

        // Axis labels
        addAxisLabel(to: scene, text: "x", position: SCNVector3(axisLength + 0.15, 0, 0), color: .red)
        addAxisLabel(to: scene, text: "y", position: SCNVector3(0, axisLength + 0.15, 0), color: .green)
        addAxisLabel(to: scene, text: "z", position: SCNVector3(0, 0, axisLength + 0.15), color: .blue)

        // Origin sphere
        let originSphere = SCNSphere(radius: 0.04)
        originSphere.firstMaterial?.diffuse.contents = UIColor.white
        originSphere.firstMaterial?.emission.contents = UIColor(white: 0.5, alpha: 1)
        let originNode = SCNNode(geometry: originSphere)
        scene.rootNode.addChildNode(originNode)
    }

    private func addAxisLine(to scene: SCNScene, direction: SCNVector3, color: UIColor, radius: Float) {
        let length = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
        let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents = color
        cylinder.firstMaterial?.emission.contents = color.withAlphaComponent(0.3)

        let node = SCNNode(geometry: cylinder)
        // SCNCylinder is along Y axis by default, centered at origin
        // We need to rotate and position it
        let midpoint = SCNVector3(direction.x / 2, direction.y / 2, direction.z / 2)
        node.position = midpoint

        // Rotate from Y axis to target direction
        let up = SCNVector3(0, 1, 0)
        let dir = SCNVector3(direction.x / length, direction.y / length, direction.z / length)
        let cross = SCNVector3(
            up.y * dir.z - up.z * dir.y,
            up.z * dir.x - up.x * dir.z,
            up.x * dir.y - up.y * dir.x
        )
        let crossLen = sqrt(cross.x * cross.x + cross.y * cross.y + cross.z * cross.z)
        let dot = up.x * dir.x + up.y * dir.y + up.z * dir.z

        if crossLen > 1e-6 {
            let angle = atan2(crossLen, dot)
            let axis = SCNVector3(cross.x / crossLen, cross.y / crossLen, cross.z / crossLen)
            node.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        } else if dot < 0 {
            node.rotation = SCNVector4(1, 0, 0, Float.pi)
        }

        scene.rootNode.addChildNode(node)
    }

    private func addAxisLabel(to scene: SCNScene, text: String, position: SCNVector3, color: UIColor) {
        let textGeo = SCNText(string: text, extrusionDepth: 0.01)
        textGeo.font = UIFont.systemFont(ofSize: 0.2, weight: .bold)
        textGeo.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.8)
        textGeo.firstMaterial?.isDoubleSided = true
        textGeo.flatness = 0.1

        let textNode = SCNNode(geometry: textGeo)
        // Center the text
        let (min, max) = textGeo.boundingBox
        let dx = (max.x - min.x) / 2
        let dy = (max.y - min.y) / 2
        textNode.pivot = SCNMatrix4MakeTranslation(dx + min.x, dy + min.y, 0)
        textNode.position = position

        // Billboard constraint so text always faces camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]

        scene.rootNode.addChildNode(textNode)
    }

    // MARK: - Quadric Surface Mesh Generation

    private func buildQuadricNode() -> SCNNode? {
        let sig = matrix.signature

        // Determine which parametric generator to use
        switch (sig.pos, sig.neg, sig.zero) {
        case (3, 0, 0):
            return buildEllipsoid()
        case (2, 1, 0):
            return buildHyperboloid1Sheet()
        case (1, 2, 0):
            return buildHyperboloid2Sheets()
        case (2, 0, 1):
            return buildEllipticCylinder()
        case (1, 1, 1):
            return buildHyperbolicCylinder()
        case (1, 0, 2):
            return buildParallelPlanes()
        default:
            // No real surface (all negative, or degenerate)
            return nil
        }
    }

    /// Generate mesh for the quadric by sampling in the eigenframe and
    /// transforming back. This avoids needing different parametrizations.
    ///
    /// For x^T A x = 1 with A = V D V^T (eigendecomposition), the surface
    /// in the eigenframe is x'^T D x' = 1 which is a standard quadric.
    /// Then we transform vertices back by V.

    // MARK: Ellipsoid: d1*x² + d2*y² + d3*z² = 1

    private func buildEllipsoid() -> SCNNode {
        let (l1, l2, l3) = matrix.eigenvalues
        let eigenvecs = computeEigenvectors()

        let r1 = 1.0 / sqrt(max(l1, 1e-10))
        let r2 = 1.0 / sqrt(max(l2, 1e-10))
        let r3 = 1.0 / sqrt(max(l3, 1e-10))

        let uSteps = 48
        let vSteps = 24

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [UInt32] = []

        for i in 0...uSteps {
            let u = Double(i) / Double(uSteps) * 2.0 * .pi
            for j in 0...vSteps {
                let v = Double(j) / Double(vSteps) * .pi
                let x = r1 * cos(u) * sin(v)
                let y = r2 * sin(u) * sin(v)
                let z = r3 * cos(v)

                // Normal in eigenframe (gradient of f = d1x²+d2y²+d3z²)
                let nx = 2.0 * l1 * x
                let ny = 2.0 * l2 * y
                let nz = 2.0 * l3 * z
                let nLen = sqrt(nx * nx + ny * ny + nz * nz)

                let worldPt = transformFromEigenframe(x: x, y: y, z: z, eigenvecs: eigenvecs)
                let worldN = transformFromEigenframe(x: nx / max(nLen, 1e-10),
                                                     y: ny / max(nLen, 1e-10),
                                                     z: nz / max(nLen, 1e-10),
                                                     eigenvecs: eigenvecs)
                vertices.append(worldPt)
                normals.append(worldN)
            }
        }

        // Build triangle strip indices
        for i in 0..<uSteps {
            for j in 0..<vSteps {
                let a = UInt32(i * (vSteps + 1) + j)
                let b = a + 1
                let c = UInt32((i + 1) * (vSteps + 1) + j)
                let d = c + 1
                indices.append(contentsOf: [a, b, c, b, d, c])
            }
        }

        return buildMeshNode(vertices: vertices, normals: normals, indices: indices)
    }

    // MARK: Hyperboloid of 1 sheet: d1*x² + d2*y² + d3*z² = 1, d3 < 0

    private func buildHyperboloid1Sheet() -> SCNNode {
        let (l1, l2, l3) = matrix.eigenvalues
        let eigenvecs = computeEigenvectors()

        // Sort so two positive come first, negative last
        var lambdas = [(l1, 0), (l2, 1), (l3, 2)]
        lambdas.sort { $0.0 > $1.0 }

        let posA = lambdas[0].0
        let posB = lambdas[1].0
        let negC = lambdas[2].0

        let rA = 1.0 / sqrt(max(posA, 1e-10))
        let rB = 1.0 / sqrt(max(posB, 1e-10))
        let rC = 1.0 / sqrt(max(-negC, 1e-10))

        // Reorder eigenvectors to match sorted eigenvalues
        let sortedEigenvecs = [eigenvecs[lambdas[0].1],
                                eigenvecs[lambdas[1].1],
                                eigenvecs[lambdas[2].1]]

        let uSteps = 48
        let vSteps = 32
        let vRange = 2.0  // parameter range for v (cosh/sinh)

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [UInt32] = []

        for i in 0...uSteps {
            let u = Double(i) / Double(uSteps) * 2.0 * .pi
            for j in 0...vSteps {
                let v = -vRange + Double(j) / Double(vSteps) * 2.0 * vRange
                let x = rA * cosh(v) * cos(u)
                let y = rB * cosh(v) * sin(u)
                let z = rC * sinh(v)

                // Normal
                let nx = 2.0 * posA * x
                let ny = 2.0 * posB * y
                let nz = 2.0 * negC * z
                let nLen = sqrt(nx * nx + ny * ny + nz * nz)

                let worldPt = transformFromEigenframe3(x: x, y: y, z: z, eigenvecs: sortedEigenvecs)
                let worldN = transformFromEigenframe3(x: nx / max(nLen, 1e-10),
                                                      y: ny / max(nLen, 1e-10),
                                                      z: nz / max(nLen, 1e-10),
                                                      eigenvecs: sortedEigenvecs)
                vertices.append(worldPt)
                normals.append(worldN)
            }
        }

        for i in 0..<uSteps {
            for j in 0..<vSteps {
                let a = UInt32(i * (vSteps + 1) + j)
                let b = a + 1
                let c = UInt32((i + 1) * (vSteps + 1) + j)
                let d = c + 1
                indices.append(contentsOf: [a, b, c, b, d, c])
            }
        }

        return buildMeshNode(vertices: vertices, normals: normals, indices: indices)
    }

    // MARK: Hyperboloid of 2 sheets: d1*x² + d2*y² + d3*z² = 1, d2,d3 < 0

    private func buildHyperboloid2Sheets() -> SCNNode {
        let (l1, l2, l3) = matrix.eigenvalues
        let eigenvecs = computeEigenvectors()

        // Sort: positive first, then negatives
        var lambdas = [(l1, 0), (l2, 1), (l3, 2)]
        lambdas.sort { $0.0 > $1.0 }

        let posA = lambdas[0].0
        let negB = lambdas[1].0
        let negC = lambdas[2].0

        let rA = 1.0 / sqrt(max(posA, 1e-10))
        let rB = 1.0 / sqrt(max(-negB, 1e-10))
        let rC = 1.0 / sqrt(max(-negC, 1e-10))

        let sortedEigenvecs = [eigenvecs[lambdas[0].1],
                                eigenvecs[lambdas[1].1],
                                eigenvecs[lambdas[2].1]]

        let uSteps = 48
        let vSteps = 16
        let vRange = 1.5

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [UInt32] = []

        // Two sheets: cosh(v) in the positive axis direction
        for sign in [1.0, -1.0] {
            let offset = UInt32(vertices.count)
            for i in 0...uSteps {
                let u = Double(i) / Double(uSteps) * 2.0 * .pi
                for j in 0...vSteps {
                    let v = Double(j) / Double(vSteps) * vRange
                    let x = sign * rA * cosh(v)
                    let y = rB * sinh(v) * cos(u)
                    let z = rC * sinh(v) * sin(u)

                    let nx = 2.0 * posA * x
                    let ny = 2.0 * negB * y
                    let nz = 2.0 * negC * z
                    let nLen = sqrt(nx * nx + ny * ny + nz * nz)

                    let worldPt = transformFromEigenframe3(x: x, y: y, z: z, eigenvecs: sortedEigenvecs)
                    let worldN = transformFromEigenframe3(x: nx / max(nLen, 1e-10),
                                                          y: ny / max(nLen, 1e-10),
                                                          z: nz / max(nLen, 1e-10),
                                                          eigenvecs: sortedEigenvecs)
                    vertices.append(worldPt)
                    normals.append(worldN)
                }
            }

            for i in 0..<uSteps {
                for j in 0..<vSteps {
                    let a = offset + UInt32(i * (vSteps + 1) + j)
                    let b = a + 1
                    let c = offset + UInt32((i + 1) * (vSteps + 1) + j)
                    let d = c + 1
                    indices.append(contentsOf: [a, b, c, b, d, c])
                }
            }
        }

        return buildMeshNode(vertices: vertices, normals: normals, indices: indices)
    }

    // MARK: Elliptic Cylinder: d1*x² + d2*y² = 1 (d3 = 0)

    private func buildEllipticCylinder() -> SCNNode {
        let (l1, l2, l3) = matrix.eigenvalues
        let eigenvecs = computeEigenvectors()

        // Two positive, one zero. Sort: positives first.
        var lambdas = [(l1, 0), (l2, 1), (l3, 2)]
        lambdas.sort { abs($0.0) > abs($1.0) }

        // Find the two positive and one zero
        var posLambdas: [(Double, Int)] = []
        var zeroIdx = 0
        for (val, idx) in lambdas {
            if abs(val) < 1e-8 {
                zeroIdx = idx
            } else {
                posLambdas.append((val, idx))
            }
        }
        guard posLambdas.count >= 2 else { return SCNNode() }

        let rA = 1.0 / sqrt(max(posLambdas[0].0, 1e-10))
        let rB = 1.0 / sqrt(max(posLambdas[1].0, 1e-10))

        let sortedEigenvecs = [eigenvecs[posLambdas[0].1],
                                eigenvecs[posLambdas[1].1],
                                eigenvecs[zeroIdx]]

        let uSteps = 48
        let height: Double = 3.0  // cylinder extends ±height along zero-eigenvalue axis

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [UInt32] = []

        for i in 0...uSteps {
            let u = Double(i) / Double(uSteps) * 2.0 * .pi
            for j in 0...1 {
                let z = j == 0 ? -height : height
                let x = rA * cos(u)
                let y = rB * sin(u)

                let nx = 2.0 * posLambdas[0].0 * x
                let ny = 2.0 * posLambdas[1].0 * y
                let nLen = sqrt(nx * nx + ny * ny)

                let worldPt = transformFromEigenframe3(x: x, y: y, z: z, eigenvecs: sortedEigenvecs)
                let worldN = transformFromEigenframe3(x: nx / max(nLen, 1e-10),
                                                      y: ny / max(nLen, 1e-10),
                                                      z: 0,
                                                      eigenvecs: sortedEigenvecs)
                vertices.append(worldPt)
                normals.append(worldN)
            }
        }

        for i in 0..<uSteps {
            let a = UInt32(i * 2)
            let b = a + 1
            let c = UInt32((i + 1) * 2)
            let d = c + 1
            indices.append(contentsOf: [a, b, c, b, d, c])
        }

        return buildMeshNode(vertices: vertices, normals: normals, indices: indices)
    }

    // MARK: Hyperbolic Cylinder: d1*x² - |d2|*y² = 1, d3 = 0

    private func buildHyperbolicCylinder() -> SCNNode {
        let (l1, l2, l3) = matrix.eigenvalues
        let eigenvecs = computeEigenvectors()

        var lambdas = [(l1, 0), (l2, 1), (l3, 2)]
        lambdas.sort { $0.0 > $1.0 }  // positive first

        var posIdx = 0, negIdx = 0, zeroIdx = 0
        var posVal = 1.0, negVal = -1.0
        for (val, idx) in lambdas {
            if abs(val) < 1e-8 { zeroIdx = idx }
            else if val > 0 { posIdx = idx; posVal = val }
            else { negIdx = idx; negVal = val }
        }

        let rA = 1.0 / sqrt(max(posVal, 1e-10))
        let rB = 1.0 / sqrt(max(-negVal, 1e-10))
        let sortedEigenvecs = [eigenvecs[posIdx], eigenvecs[negIdx], eigenvecs[zeroIdx]]

        let uSteps = 32
        let uRange = 2.0
        let height = 3.0

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [UInt32] = []

        for sign in [1.0, -1.0] {
            let offset = UInt32(vertices.count)
            for i in 0...uSteps {
                let u = -uRange + Double(i) / Double(uSteps) * 2.0 * uRange
                for j in 0...1 {
                    let z = j == 0 ? -height : height
                    let x = sign * rA * cosh(u)
                    let y = rB * sinh(u)

                    let nx = 2.0 * posVal * x
                    let ny = 2.0 * negVal * y
                    let nLen = sqrt(nx * nx + ny * ny)

                    let worldPt = transformFromEigenframe3(x: x, y: y, z: z, eigenvecs: sortedEigenvecs)
                    let worldN = transformFromEigenframe3(x: nx / max(nLen, 1e-10),
                                                          y: ny / max(nLen, 1e-10),
                                                          z: 0,
                                                          eigenvecs: sortedEigenvecs)
                    vertices.append(worldPt)
                    normals.append(worldN)
                }
            }

            for i in 0..<uSteps {
                let a = offset + UInt32(i * 2)
                let b = a + 1
                let c = offset + UInt32((i + 1) * 2)
                let d = c + 1
                indices.append(contentsOf: [a, b, c, b, d, c])
            }
        }

        return buildMeshNode(vertices: vertices, normals: normals, indices: indices)
    }

    // MARK: Parallel Planes: d1*x² = 1 → x = ±1/√d1

    private func buildParallelPlanes() -> SCNNode {
        let (l1, l2, l3) = matrix.eigenvalues
        let eigenvecs = computeEigenvectors()

        // Find the one nonzero eigenvalue
        var nonzeroIdx = 0
        var nonzeroVal = 1.0
        var zeroIdxes: [Int] = []
        for (i, l) in [l1, l2, l3].enumerated() {
            if abs(l) > 1e-8 {
                nonzeroIdx = i
                nonzeroVal = l
            } else {
                zeroIdxes.append(i)
            }
        }
        guard nonzeroVal > 0 else { return SCNNode() }

        let dist = 1.0 / sqrt(nonzeroVal)
        let sortedEigenvecs = [eigenvecs[nonzeroIdx],
                                eigenvecs[zeroIdxes.first ?? 1],
                                eigenvecs[zeroIdxes.last ?? 2]]

        let planeSize = 3.0

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [UInt32] = []

        for sign in [1.0, -1.0] {
            let offset = UInt32(vertices.count)
            let corners = [
                (sign * dist, -planeSize, -planeSize),
                (sign * dist,  planeSize, -planeSize),
                (sign * dist,  planeSize,  planeSize),
                (sign * dist, -planeSize,  planeSize),
            ]
            for (cx, cy, cz) in corners {
                let worldPt = transformFromEigenframe3(x: cx, y: cy, z: cz, eigenvecs: sortedEigenvecs)
                let worldN = transformFromEigenframe3(x: sign, y: 0, z: 0, eigenvecs: sortedEigenvecs)
                vertices.append(worldPt)
                normals.append(worldN)
            }
            indices.append(contentsOf: [offset, offset + 1, offset + 2,
                                         offset, offset + 2, offset + 3])
        }

        return buildMeshNode(vertices: vertices, normals: normals, indices: indices, opacity: 0.5)
    }

    // MARK: - Mesh Helpers

    private func buildMeshNode(vertices: [SCNVector3], normals: [SCNVector3],
                                indices: [UInt32], opacity: Double = 0.7) -> SCNNode {
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        let element = SCNGeometryElement(data: indexData,
                                          primitiveType: .triangles,
                                          primitiveCount: indices.count / 3,
                                          bytesPerIndex: MemoryLayout<UInt32>.size)

        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])

        let material = SCNMaterial()
        let uiColor = UIColor(accentColor)
        material.diffuse.contents = uiColor.withAlphaComponent(CGFloat(opacity))
        material.specular.contents = UIColor.white
        material.shininess = 0.3
        material.isDoubleSided = true
        material.transparency = CGFloat(opacity)
        material.lightingModel = .blinn
        geometry.materials = [material]

        return SCNNode(geometry: geometry)
    }

    // MARK: - Eigenvector Computation

    /// Compute eigenvectors for the 3x3 symmetric matrix.
    /// Returns array of 3 vectors as (x, y, z) tuples.
    private func computeEigenvectors() -> [(Double, Double, Double)] {
        let (l1, l2, l3) = matrix.eigenvalues
        let v1 = eigenvectorFor(lambda: l1, avoidIndex: nil)
        let v2 = eigenvectorFor(lambda: l2, avoidIndex: 0)
        let v3 = crossProduct(v1, v2)
        return [v1, v2, v3]
    }

    /// Compute eigenvector for a given eigenvalue using (A - λI) null space.
    private func eigenvectorFor(lambda: Double, avoidIndex: Int?) -> (Double, Double, Double) {
        let m = matrix.values
        // A - λI
        let r0 = (m[0][0] - lambda, m[0][1], m[0][2])
        let r1 = (m[1][0], m[1][1] - lambda, m[1][2])
        let r2 = (m[2][0], m[2][1], m[2][2] - lambda)

        // Find the null vector by taking cross products of rows
        let candidates = [
            crossProduct(r0, r1),
            crossProduct(r0, r2),
            crossProduct(r1, r2),
        ]

        var best = (1.0, 0.0, 0.0)
        var bestLen = 0.0

        for c in candidates {
            let len = sqrt(c.0 * c.0 + c.1 * c.1 + c.2 * c.2)
            if len > bestLen {
                bestLen = len
                best = (c.0 / len, c.1 / len, c.2 / len)
            }
        }

        if bestLen < 1e-12 {
            // Degenerate: eigenvalue has multiplicity. Return a canonical vector.
            if avoidIndex == 0 { return (0, 1, 0) }
            return (1, 0, 0)
        }

        return best
    }

    private func crossProduct(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> (Double, Double, Double) {
        (a.1 * b.2 - a.2 * b.1,
         a.2 * b.0 - a.0 * b.2,
         a.0 * b.1 - a.1 * b.0)
    }

    /// Transform a point from the eigenframe to world coordinates.
    private func transformFromEigenframe(x: Double, y: Double, z: Double,
                                          eigenvecs: [(Double, Double, Double)]) -> SCNVector3 {
        let v0 = eigenvecs[0]
        let v1 = eigenvecs[1]
        let v2 = eigenvecs[2]
        return SCNVector3(
            Float(x * v0.0 + y * v1.0 + z * v2.0),
            Float(x * v0.1 + y * v1.1 + z * v2.1),
            Float(x * v0.2 + y * v1.2 + z * v2.2)
        )
    }

    /// Transform from sorted eigenframe (possibly reordered eigenvectors).
    private func transformFromEigenframe3(x: Double, y: Double, z: Double,
                                           eigenvecs: [(Double, Double, Double)]) -> SCNVector3 {
        let v0 = eigenvecs[0]
        let v1 = eigenvecs[1]
        let v2 = eigenvecs[2]
        return SCNVector3(
            Float(x * v0.0 + y * v1.0 + z * v2.0),
            Float(x * v0.1 + y * v1.1 + z * v2.1),
            Float(x * v0.2 + y * v1.2 + z * v2.2)
        )
    }
}
