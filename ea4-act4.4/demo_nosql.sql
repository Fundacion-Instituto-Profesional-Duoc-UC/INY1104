// Insertar 100 Registros de Ejemplo en la Colección Usuarios
for (let i = 1; i <= 100; i++) {
  db.Usuarios.insertOne({
    UsuarioID: i,
    Nombre: `Usuario${i}`,
    CorreoElectronico: `usuario${i}@example.com`,
    Contraseña: `contrasena${i}`
  });
}

// Insertar 100 Registros de Ejemplo en la Colección Productos
for (let i = 1; i <= 100; i++) {
  db.Productos.insertOne({
    ProductoID: i,
    Nombre: `Producto${i}`,
    Descripcion: `Descripción del Producto ${i}`,
    Precio: parseFloat((Math.random() * 100).toFixed(2)),
    Stock: Math.floor(Math.random() * 100)
  });
}

// Insertar 100 Registros de Ejemplo en la Colección Pedidos
for (let i = 1; i <= 100; i++) {
  db.Pedidos.insertOne({
    PedidoID: i,
    UsuarioID: Math.floor(Math.random() * 100),
    Fecha: new Date(new Date('2022-01-01').getTime() + i * 24 * 60 * 60 * 1000),
    Estado: i % 2 === 0 ? 'En Proceso' : 'Entregado'
  });
}

