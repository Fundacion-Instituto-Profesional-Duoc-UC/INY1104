-- Crear Tabla Usuarios
CREATE TABLE Usuarios (
  UsuarioID INT PRIMARY KEY,
  Nombre VARCHAR(255),
  CorreoElectronico VARCHAR(255),
  Contraseña VARCHAR(255)
);

-- Crear Tabla Productos
CREATE TABLE Productos (
  ProductoID INT PRIMARY KEY,
  Nombre VARCHAR(255),
  Descripcion TEXT,
  Precio DECIMAL(10, 2),
  Stock INT
);

-- Crear Tabla Pedidos
CREATE TABLE Pedidos (
  PedidoID INT PRIMARY KEY,
  UsuarioID INT,
  Fecha DATE,
  Estado VARCHAR(50),
  FOREIGN KEY (UsuarioID) REFERENCES Usuarios(UsuarioID)
);

-- Insertar 100 Registros de Ejemplo en la Tabla Usuarios
INSERT INTO Usuarios (UsuarioID, Nombre, CorreoElectronico, Contraseña)
SELECT
  t.n,
  CONCAT('Usuario', t.n),
  CONCAT('usuario', t.n, '@example.com'),
  CONCAT('contrasena', t.n)
FROM
  (SELECT ROW_NUMBER() OVER () AS n FROM INFORMATION_SCHEMA.TABLES) t
WHERE
  t.n <= 100;

-- Insertar 100 Registros de Ejemplo en la Tabla Productos
INSERT INTO Productos (ProductoID, Nombre, Descripcion, Precio, Stock)
SELECT
  t.n,
  CONCAT('Producto', t.n),
  CONCAT('Descripción del Producto ', t.n),
  ROUND(RAND() * 100, 2),
  ROUND(RAND() * 100)
FROM
  (SELECT ROW_NUMBER() OVER () AS n FROM INFORMATION_SCHEMA.TABLES) t
WHERE
  t.n <= 100;

-- Insertar 100 Registros de Ejemplo en la Tabla Pedidos
INSERT INTO Pedidos (PedidoID, UsuarioID, Fecha, Estado)
SELECT
  t.n,
  ROUND(RAND() * 100),
  DATE_ADD('2022-01-01', INTERVAL t.n DAY),
  CASE WHEN t.n % 2 = 0 THEN 'En Proceso' ELSE 'Entregado' END
FROM
  (SELECT ROW_NUMBER() OVER () AS n FROM INFORMATION_SCHEMA.TABLES) t
WHERE
  t.n <= 100;

