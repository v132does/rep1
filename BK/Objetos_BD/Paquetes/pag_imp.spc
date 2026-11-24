create or replace package it.PAG_IMP is

  -- Author  : AGUSTIN MEZA
  -- Created : 12/02/2005 05:44:49 p.m.
  -- Purpose : Manejo de  impresiones en Java

v_cod_oficina number(3) := 1;   -- oficina del usuario
v_ancho   number(3) := 80;      -- ancho de impresion

-- proc. para setear la oficina del usuario
procedure PR_SET_OFICINA
      (p_cod_oficina IN NUMBER);

-- proc. para setear el ancho del reporte
procedure PR_SET_ANCHO
      (p_ancho IN NUMBER);

-- impresion de la cabecera de impresion  ajustada al tama—o de la hoja
procedure PR_IMP_CAB_AJUSTADA
      (p_texto       IN OUT VARCHAR2,      -- texto que se recibe y que se carga con las lineas
       p_titulo      IN VARCHAR2,          -- Titulo a imprimir
       p_sub_titulo  IN VARCHAR2,          -- Sub titulo a imprimir
       p_lin_antes   IN NUMBER DEFAULT 0,  -- lineas antes de la cabecera
       p_lin_despues IN NUMBER DEFAULT 0); -- lineas a saltar despues de la cabecera

-- impresion de la cabecera de impresion  centrada
procedure PR_IMP_CAB_CENTRADA
      (p_texto       IN OUT VARCHAR2,      -- texto que se recibe y que se carga con las lineas
       p_titulo      IN VARCHAR2,          -- Titulo a imprimir
       p_sub_titulo  IN VARCHAR2,          -- Sub titulo a imprimir
       p_lin_antes   IN NUMBER DEFAULT 0,  -- lineas antes de la cabecera
       p_lin_despues IN NUMBER DEFAULT 0, -- lineas a saltar despues de la cabecera
       p_imp_oficina in varchar2 default 'S'); --indica si se imprime o no el nombre de la oficina

-- impresion de la cabecera de impresion  centrada sin el nombre de la oficina
procedure PR_IMP_CAB_COM_CENTRADA
      (p_texto       IN OUT VARCHAR2,      -- texto que se recibe y que se carga con las lineas
       p_titulo      IN VARCHAR2,          -- Titulo a imprimir
       p_sub_titulo  IN VARCHAR2,          -- Sub titulo a imprimir
       p_lin_antes   IN NUMBER DEFAULT 0,  -- lineas antes de la cabecera
       p_lin_despues IN NUMBER DEFAULT 0); -- lineas a saltar despues de la cabecera

-- impresion del pie de pagina
procedure PR_IMP_PIE
      (p_texto       IN OUT VARCHAR2,  -- texto que contiene los datos
       p_lin_antes   IN NUMBER);       -- lineas antes de imprimir

  -- procecimiento que adiciona una linea al campo texto
procedure PR_IMP_LINEA
      (p_texto     IN OUT clob,        -- texto que se recibe y que se carga con las lineas
       p_dato      IN clob,            -- Dato a imprimir
       p_lin_antes IN NUMBER DEFAULT 0,    -- lineas a saltar antes, por defecto 0
       p_col_antes IN NUMBER DEFAULT 0,
       p_centrado IN VARCHAR2 DEFAULT 'N');   -- cuantas letras se adiciona antes,por def 0

-- procedimiento para imprimir negrita
procedure PR_NEGRITA
      (p_texto     IN OUT VARCHAR2,        -- texto que se recibe y que se carga con las lineas
       p_sino      IN VARCHAR2 DEFAULT 'S' -- Prende o apaga
       );

-- procedimiento para imprimir CONDENSADO
procedure PR_CONDENSADO
      (p_texto     IN OUT VARCHAR2,        -- texto que se recibe y que se carga con las lineas
       p_sino      IN VARCHAR2 DEFAULT 'S' -- Prende o apaga
       );

-- procedimiento para inicializar la impresora
procedure PR_INI_IMPRESORA
      (p_texto     IN OUT VARCHAR2         -- texto que se recibe y que se carga con las lineas
       );
-- procedimiento para realizar el corte del papel
procedure PR_COR_PAPEL
      (p_texto     IN OUT VARCHAR2        -- texto que se recibe y que se carga con las lineas
       );

-- procedimiento para imprimir enfatizado
procedure PR_ENFATIZADO
      (p_texto     IN OUT VARCHAR2,        -- texto que se recibe y que se carga con las lineas
       p_sino      IN VARCHAR2 DEFAULT 'S' -- Prende o apaga
       );

-- proc. para setear la impresora, Este debe ser siempre el que inicia el texto de la impresion
function FU_SET_IMPRESORA
        (p_numero IN NUMBER,
         p_mensaje in VARCHAR2 DEFAULT null)
  return varchar2;

procedure PR_SET_IMPRESORA
      (p_texto     IN OUT VARCHAR2,        -- texto que se recibe y que se carga con las lineas
       p_numero IN NUMBER,
       p_mensaje in VARCHAR2 DEFAULT null
       );

end PAG_IMP;
/

