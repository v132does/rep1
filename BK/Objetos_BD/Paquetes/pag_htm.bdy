create or replace package body it.pag_htm is

procedure PR_ENCABEZADO is
begin
  v_texto := '<html>'||v_salto;
  v_texto := v_texto||'<head>'||v_salto;
  v_texto := v_texto||'<title>[IT CONSULTORES</title>'||v_salto;
  v_texto := v_texto||'<!-- Desarrollado por IT Consultores. Tel: (595-21) 208-664 -->'||v_salto;
  v_texto := v_texto||'<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">'||v_salto;
  v_texto := v_texto||'<link href="css/estilos.css" rel="stylesheet" type="text/css">'||v_salto;

  v_texto := v_texto||'</head>'||v_salto;
end;

procedure PR_PIE is
begin
  v_texto := v_texto||'</html>';
end;

procedure PR_CUERPO
      (p_sino          IN VARCHAR2 DEFAULT 'S',  -- Prende o apaga
       p_formato       in varchar2 default null) IS
begin
   if nvl(p_sino,'S') = 'S' then -- se agrega el tag
      v_texto := v_texto||'<body';
      if p_formato is not null then
         v_texto := v_texto||' '||p_formato;
      end if;
      v_texto := v_texto||'>'||v_salto;
      v_texto := v_texto||'<font face="Arial, Helvetica, sans-serif" color=#000000 size=1>';
   else -- cierra el tag
      v_texto := v_texto||'</font>'||'</body>'||v_salto;
   end if;
end;

-- procedimiento para generar o cerrar tabla
procedure PR_TABLA
      (p_sino      IN VARCHAR2 DEFAULT 'S',  -- Prende o apaga
       p_width     IN NUMBER DEFAULT NULL,   -- longitud de la tabla
       p_height    IN NUMBER DEFAULT NULL,   -- altura
       p_borde     IN NUMBER DEFAULT 0       -- borde
       ) IS
begin
   if nvl(p_sino,'S') = 'S' then -- se agrega el tag
      v_texto := v_texto||'<table';
      if p_width is not null then
         v_texto := v_texto||' width='||p_width;
      end if;
      if p_height is not null then
         v_texto := v_texto||' height='||p_height;
      end if;
      v_texto := v_texto||' border='||p_borde||'>'||v_salto;

   else -- cierra el tag
      v_texto := v_texto||'</table>'||v_salto;
   end if;
end PR_TABLA;


procedure PR_FILA
      (p_sino          IN VARCHAR2 DEFAULT 'S',  -- Prende o apaga
       p_formato       in varchar2 default null) IS
begin
   if nvl(p_sino,'S') = 'S' then -- se agrega el tag
      v_texto := v_texto||'<tr class="negro"';
      if p_formato is not null then
         v_texto := v_texto||' '||p_formato;
      end if;
      v_texto := v_texto||'>'||v_salto;
   else -- cierra el tag
      v_texto := v_texto||'</tr>'||v_salto;
   end if;
end PR_FILA;

-- procedimiento para generar una columna
procedure PR_COLUMNA
      (p_texto       in VARCHAR2 DEFAULT null, -- texto agregado
       p_width       IN NUMBER DEFAULT NULL,   -- longitud de la tabla
       p_alineacion  in varchar2 default 'left',
       p_negrita     in varchar2 default 'N',
       p_formato     in varchar2 default null
       ) IS
begin
    v_texto := v_texto||'<td';
    if p_width is not null then
       v_texto := v_texto||' width='||p_width;
    end if;
    if p_alineacion is not null then
       v_texto := v_texto||' align="'||p_alineacion||'"';
    end if;
    if p_formato is not null then
       v_texto := v_texto||' '||p_formato;
    end if;
    v_texto := v_texto||'>'/*||'<span class="gris">'*/;
    if p_negrita='S' then
      v_texto := v_texto||'<b>'||nvl(p_texto,'&nbsp;')||'</b>';
    else
      v_texto := v_texto||nvl(p_texto,'&nbsp;');
    end if;
    v_texto := v_texto||/*'</span>'||*/'</td>'||v_salto;
exception
   when others then raise_application_error(-20333,'columna '||length(v_texto)||'-'||sqlerrm);
end PR_COLUMNA;

procedure PR_TEXTO
      (p_texto in varchar2) is
begin
  v_texto := v_texto || p_texto;
end;

function FU_CON_HTML(p_texto in varchar2)
         return varchar2 is
v_texto varchar2(1000);
--Función que convierte caracteres especiales a sus correspondientes entidades de HTML
begin
	v_texto:=replace(p_texto,'á','&aacute;');
	v_texto:=replace(v_texto,'é','&eacute;');
	v_texto:=replace(v_texto,'í','&iacute;');
	v_texto:=replace(v_texto,'ó','&oacute;');
	v_texto:=replace(v_texto,'ú','&uacute;');
	v_texto:=replace(v_texto,'Á','&Aacute;');
	v_texto:=replace(v_texto,'É','&Eacute;');
	v_texto:=replace(v_texto,'Í','&Iacute;');
	v_texto:=replace(v_texto,'Ó','&Oacute;');
	v_texto:=replace(v_texto,'Ú','&Uacute;');
	v_texto:=replace(v_texto,'ñ','&ntilde;');
	v_texto:=replace(v_texto,'Ñ','&Ntilde;');
 	v_texto:=replace(v_texto,'°','&deg;');
	return v_texto;
end;

end pag_htm;
/

