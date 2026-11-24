create or replace package it.pag_htm is

  -- Author  : AGUSTIN MEZA
  -- Created : 05/10/2007 04:11:33 p.m.
  -- Purpose : generacion automática de paginas html

v_texto long; --clob;--varchar2(4000);
v_salto varchar2(2) := '' ; --chr(10); --||chr(13);

procedure PR_ENCABEZADO;

procedure PR_PIE;
procedure PR_CUERPO
      (p_sino          IN VARCHAR2 DEFAULT 'S',  -- Prende o apaga
       p_formato       in varchar2 default null);
-- procedimiento para generar o cerrar tabla
procedure PR_TABLA
      (p_sino      IN VARCHAR2 DEFAULT 'S',  -- Prende o apaga
       p_width     IN NUMBER DEFAULT NULL,   -- longitud de la tabla
       p_height    IN NUMBER DEFAULT NULL,   -- altura
       p_borde     IN NUMBER DEFAULT 0       -- borde
       );
procedure PR_FILA
      (p_sino          IN VARCHAR2 DEFAULT 'S',  -- Prende o apaga
       p_formato       in varchar2 default null);
-- procedimiento para generar una columna
procedure PR_COLUMNA
      (p_texto       in VARCHAR2 DEFAULT NULL, -- texto agregado
       p_width       IN NUMBER DEFAULT NULL,   -- longitud de la tabla
       p_alineacion  in varchar2 default 'left',
       p_negrita     in varchar2 default 'N',
       p_formato     in varchar2 default null
       );
-- permite agregar cualquier texto
procedure PR_TEXTO
      (p_texto in varchar2);
-- retorna el texto reemplazando por el html entities correspondiente
function FU_CON_HTML(p_texto in varchar2)
         return varchar2;

end pag_htm;
/

