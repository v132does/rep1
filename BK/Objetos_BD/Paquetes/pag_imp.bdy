create or replace package body it.PAG_IMP is

-- seteo de la oficina del usuario
procedure PR_SET_OFICINA
      (p_cod_oficina IN NUMBER) is
begin
  v_cod_oficina := p_cod_oficina;
end;

--- proc. para setear el ancho del reporte
procedure PR_SET_ANCHO
      (p_ancho IN NUMBER) is
begin
   v_ancho := p_ancho;
end;

-- procecimiento que imprime la cabecera por defecto ajustada al tamaño de la hoja
procedure PR_IMP_CAB_AJUSTADA
      (p_texto       IN OUT VARCHAR2,      -- texto que se recibe y que se carga con las lineas
       p_titulo      IN VARCHAR2,          -- Titulo a imprimir
       p_sub_titulo  IN VARCHAR2,          -- Sub titulo a imprimir
       p_lin_antes   IN NUMBER DEFAULT 0,  -- lineas antes de la cabecera
       p_lin_despues IN NUMBER DEFAULT 0)  -- lineas a saltar despues de la cabecera
   is

v_linea varchar2(200);      -- contiene el dato de una linea
v_col_antes number(4);      -- letras antes de una frase
begin
   -- adiciono los enters necesarios como lineas antes de la cabecera
   for i in 1..nvl(p_lin_antes,0)  loop
       p_texto := p_texto || '~';
   end loop;

   -- adiciono el nombre de la Entidad
   v_linea := fug_obt_nom_entidad;

   -- agrego la fecha al extremo izquierdo
   v_col_antes := v_ancho - length(v_linea) - 15;
   v_linea := v_linea || lpad(' ',nvl(v_col_antes,0),' ')||'Fecha: '||to_char(sysdate,'dd/mm/yy');
   p_texto := p_texto || v_linea || '~';

   -- agrego la oficina y la hora
   v_linea := fue_obt_des_oficina(v_cod_oficina);
   -- agrego la hora al extremo izquierdo
   v_col_antes := v_ancho - length(v_linea) - 15;
   v_linea := v_linea || lpad(' ',nvl(v_col_antes,0),' ')||'Hora : '||to_char(sysdate,'hh24:mi:ss');
   p_texto := p_texto || v_linea || '~';

   if p_titulo is not null then
     -- agrego el titulo centrado en la longitud
     p_texto := p_texto || lpad(' ',trunc((v_ancho - length(p_titulo))/2),' ')||p_titulo||'~';
   end if;

   if p_sub_titulo is not null then
     -- agrego el titulo centrado en la longitud
     p_texto := p_texto || lpad(' ',trunc((v_ancho - length(p_sub_titulo))/2),' ')||p_sub_titulo||'~';
   end if;

   -- adiciono los enters necesarios como lineas despues de la cabecera
   for i in 1..nvl(p_lin_despues,0)  loop
       p_texto := p_texto || '~';
   end loop;

end PR_IMP_CAB_AJUSTADA;

-- procecimiento que imprime la cabecera por defecto, centrada en todo el texto
procedure PR_IMP_CAB_CENTRADA
      (p_texto       IN OUT VARCHAR2,      -- texto que se recibe y que se carga con las lineas
       p_titulo      IN VARCHAR2,          -- Titulo a imprimir
       p_sub_titulo  IN VARCHAR2,          -- Sub titulo a imprimir
       p_lin_antes   IN NUMBER DEFAULT 0,  -- lineas antes de la cabecera
       p_lin_despues IN NUMBER DEFAULT 0,  -- lineas a saltar despues de la cabecera
       p_imp_oficina in varchar2 default 'S') --indica si se imprime o no el nombre de la oficina
   is

v_linea       varchar2(200); -- contiene el dato de una linea
v_nom_entidad varchar2(200); -- nombre de la entidad
v_nom_entidad1 varchar2(200);--
v_nom_entidad2 varchar2(200);--
v_nro_ruc     varchar2(20);  -- numero de ruc de la entidad
v_des_oficina varchar2(100); -- nombre de la oficina
v_dir_oficina varchar2(200); -- direccion de la oficina
v_tel_oficina varchar2(100); -- telefono de la oficina
v_mos_ruc     varchar2(1):= nvl(fug_obt_pardinamico('MOS_RUC_CAJA'),'N');



begin
   -- adiciono los enters necesarios como lineas antes de la cabecera
   for i in 1..nvl(p_lin_antes,0)  loop
       p_texto := p_texto || '~';
   end loop;

   -- busco datos de la entidad y la oficina
   begin
      select a.nom_entidad, c.nro_documento, b.descripcion, b.direccion, b.telefono,
             trim(substr(a.nom_entidad,1,instr(a.nom_entidad,'Paraguay S.A.')-1)),
             trim(substr(a.nom_entidad,instr(a.nom_entidad,'Paraguay S.A.'),
             (length(a.nom_entidad)- instr(a.nom_entidad,'Paraguay S.A.'))
             ))
        into v_nom_entidad, v_nro_ruc, v_des_oficina, v_dir_oficina, v_tel_oficina,
             v_nom_entidad1, v_nom_entidad2
        from ba_personas c, ba_oficinas b, ge_par_generales a
       where b.cod_oficina = v_cod_oficina
         and c.cod_persona = a.cod_persona;
   exception
      when others then
         raise_application_error(-20000,'Leyendo datos de la Oficina '||sqlerrm);
   end;
   --wa: 01/2021 Para new branding
   v_nom_entidad1:= fug_obt_nom('L1');
   v_nom_entidad2:= fug_obt_nom('L2');

   -- adiciono el nombre de la Entidad centrado
   --pr_enfatizado(p_texto); -- inicializa negrita
   -- Comentado para incluir el texto Paraguay S.A. en una nueva linea. 02/09/2009
   ----p_texto := p_texto || lpad(' ',trunc(((v_ancho/2) - length(v_nom_entidad))/2),' ')||v_nom_entidad||'~';
     p_texto := p_texto ||'    '|| lpad(' ',trunc(((v_ancho/2) - length(v_nom_entidad1))/2),' ')||v_nom_entidad1||'~';
     p_texto := p_texto || lpad(' ',trunc((v_ancho - length(v_nom_entidad2))/2),' ')||v_nom_entidad2||'~';

   --pr_enfatizado(p_texto,'N'); -- apaga negrita
   if p_imp_oficina = 'S' then
     -- adiciono el nombre de la oficina centrado
     p_texto := p_texto || lpad(' ',trunc((v_ancho - length(v_des_oficina))/2),' ')||v_des_oficina||'~';
   end if;
   -- adiciono la direccion de la oficina centrada
   p_texto := p_texto || lpad(' ',trunc((v_ancho - length(v_dir_oficina))/2),' ')||v_dir_oficina||'~';
   -- adiciono el telefono centrado
   if upper(substr(v_tel_oficina,1,1)) = 'T' then
      v_linea :=  v_tel_oficina;
   else
      v_linea := 'TEL: '||v_tel_oficina;
   end if;
   p_texto := p_texto || lpad(' ',trunc((v_ancho - length(v_linea))/2),' ')||v_linea||'~';
   -- adiciono el ruc de la empresa
   --wa: 01/2021 Para new branding(No se mostrará RUC)
   if upper(v_mos_ruc) = 'S' then
       v_linea := 'R.U.C.: '||v_nro_ruc;
       p_texto := p_texto || lpad(' ',trunc((v_ancho - length(v_linea))/2),' ')||v_linea||'~';
   end if;
   -- agrego la linea de separacion
   p_texto := p_texto || lpad('-',v_ancho,'-') || '~';

   -- fecha y hora centrada
   --v_linea := 'Fecha: '||to_char(sysdate,'dd/mm/yy')||'  '||to_char(sysdate,'hh24:mi:ss');
   --p_texto := p_texto || lpad(' ',trunc((v_ancho - length(v_linea))/2),' ')||v_linea||'~';

   if p_titulo is not null then
     -- agrego el titulo centrado en la longitud
     p_texto := p_texto || lpad(' ',trunc((v_ancho - length(p_titulo))/2),' ')||p_titulo||'~';
   end if;

   if p_sub_titulo is not null then
     -- agrego el titulo centrado en la longitud
     p_texto := p_texto || lpad(' ',trunc((v_ancho - length(p_sub_titulo))/2),' ')||p_sub_titulo||'~';
   end if;

   -- agrego la linea de separacion
   p_texto := p_texto || lpad('-',v_ancho,'-') || '~';

   -- adiciono los enters necesarios como lineas despues de la cabecera
   for i in 1..nvl(p_lin_despues,0)  loop
       p_texto := p_texto || '~';
   end loop;

end PR_IMP_CAB_CENTRADA;

-- procecimiento que imprime la cabecera por defecto, centrada en todo el texto sin el nombre de la oficina centrado
procedure PR_IMP_CAB_COM_CENTRADA
      (p_texto       IN OUT VARCHAR2,      -- texto que se recibe y que se carga con las lineas
       p_titulo      IN VARCHAR2,          -- Titulo a imprimir
       p_sub_titulo  IN VARCHAR2,          -- Sub titulo a imprimir
       p_lin_antes   IN NUMBER DEFAULT 0,  -- lineas antes de la cabecera
       p_lin_despues IN NUMBER DEFAULT 0)  -- lineas a saltar despues de la cabecera
   is

v_linea       varchar2(200); -- contiene el dato de una linea
v_nom_entidad varchar2(200); -- nombre de la entidad
v_nro_ruc     varchar2(20);  -- numero de ruc de la entidad
v_des_oficina varchar2(100); -- nombre de la oficina
v_dir_oficina varchar2(200); -- direccion de la oficina
v_tel_oficina varchar2(100); -- telefono de la oficina

begin
   -- adiciono los enters necesarios como lineas antes de la cabecera
   for i in 1..nvl(p_lin_antes,0)  loop
       p_texto := p_texto || '~';
   end loop;

   -- busco datos de la entidad y la oficina
   begin
      select a.nom_entidad, c.nro_documento, b.descripcion, b.direccion, b.telefono
        into v_nom_entidad, v_nro_ruc, v_des_oficina, v_dir_oficina, v_tel_oficina
        from ba_personas c, ba_oficinas b, ge_par_generales a
       where b.cod_oficina = v_cod_oficina
         and c.cod_persona = a.cod_persona;
   exception
      when others then
         raise_application_error(-20000,'Leyendo datos de la Oficina '||sqlerrm);
   end;
   -- adiciono el nombre de la Entidad centrado
   p_texto := p_texto || lpad(' ',trunc((v_ancho - length(v_nom_entidad))/2),' ')||v_nom_entidad||'~';
   -- adiciono la direccion de la oficina centrada
   p_texto := p_texto || lpad(' ',trunc((v_ancho - length(v_dir_oficina))/2),' ')||v_dir_oficina||'~';
   -- adiciono el telefono centrado
   if upper(substr(v_tel_oficina,1,1)) = 'T' then
      v_linea :=  v_tel_oficina;
   else
      v_linea := 'TEL: '||v_tel_oficina;
   end if;
   p_texto := p_texto || lpad(' ',trunc((v_ancho - length(v_linea))/2),' ')||v_linea||'~';
   -- adiciono el ruc de la empresa
   v_linea := 'R.U.C.: '||v_nro_ruc;
   p_texto := p_texto || lpad(' ',trunc((v_ancho - length(v_linea))/2),' ')||v_linea||'~';

   -- agrego la linea de separacion
   p_texto := p_texto || lpad('-',v_ancho,'-') || '~';

   -- fecha y hora centrada
   --v_linea := 'Fecha: '||to_char(sysdate,'dd/mm/yy')||'  '||to_char(sysdate,'hh24:mi:ss');
   --p_texto := p_texto || lpad(' ',trunc((v_ancho - length(v_linea))/2),' ')||v_linea||'~';

   if p_titulo is not null then
     -- agrego el titulo centrado en la longitud
     p_texto := p_texto || lpad(' ',trunc((v_ancho - length(p_titulo))/2),' ')||p_titulo||'~';
   end if;

   if p_sub_titulo is not null then
     -- agrego el titulo centrado en la longitud
     p_texto := p_texto || lpad(' ',trunc((v_ancho - length(p_sub_titulo))/2),' ')||p_sub_titulo||'~';
   end if;

   -- agrego la linea de separacion
   p_texto := p_texto || lpad('-',v_ancho,'-') || '~';

   -- adiciono los enters necesarios como lineas despues de la cabecera
   for i in 1..nvl(p_lin_despues,0)  loop
       p_texto := p_texto || '~';
   end loop;

end PR_IMP_CAB_COM_CENTRADA;

-- impresion del pie de pagina
procedure PR_IMP_PIE
      (p_texto       IN OUT VARCHAR2,  -- texto que contiene los datos
       p_lin_antes   IN NUMBER)        -- lineas antes de imprimir
   is
v_comentario varchar2(200) := '*** Gracias por su Preferencia! ***';
begin
   -- adiciono los enters necesarios como lineas antes del pie
   for i in 1..nvl(p_lin_antes,0)  loop
       p_texto := p_texto || '~';
   end loop;

   -- agrego la linea final del archivo
   p_texto := p_texto || lpad('-',v_ancho,'-') || '~';
   -- Agrego el comentario final
   p_texto := p_texto ||lpad(' ',trunc((v_ancho - length(v_comentario))/2),' ')||v_comentario||'~';
end;


-- procecimiento que adiciona una linea al campo texto
procedure PR_IMP_LINEA
      (p_texto     IN OUT clob,        -- texto que se recibe y que se carga con las lineas
       p_dato      IN clob,            -- Dato a imprimir
       p_lin_antes IN NUMBER DEFAULT 0,    -- lineas a saltar antes, por defecto 0
       p_col_antes IN NUMBER DEFAULT 0,
       p_centrado  IN VARCHAR2 DEFAULT 'N') IS -- cuantas letras se adiciona antes,por def 0
begin
   -- adiciono los enters necesarios como lineas antes se desea imprimir
   for i in 1..nvl(p_lin_antes,0)  loop
       p_texto := p_texto || '~';
   end loop;
   if nvl(p_centrado,'N') = 'N' then
     -- adiciono espacios necesarios antes y luego el dato
      p_texto := p_texto || lpad(' ',nvl(p_col_antes,0),' ')||p_dato;
   else
      p_texto := p_texto || lpad(' ',nvl(p_col_antes,0),' ')||
                 lpad(' ',trunc((v_ancho - length(p_dato))/2),' ')||p_dato;
   end if;
end PR_IMP_LINEA;

-- procedimiento para imprimir negrita
procedure PR_NEGRITA
      (p_texto     IN OUT VARCHAR2,        -- texto que se recibe y que se carga con las lineas
       p_sino      IN VARCHAR2 DEFAULT 'S' -- Prende o apaga
       ) IS
begin
   if nvl(p_sino,'S') = 'S' then -- se imprime la negrita
      --p_texto := p_texto||chr(27)||'E';
      p_texto := p_texto||chr(27)||'!'||chr(17);
   else -- vuelve al normal
      -- p_texto := p_texto||chr(27)||'F';
      p_texto := p_texto||chr(27)||'!'||chr(1);
   end if;
end PR_NEGRITA;

-- procedimiento para imprimir enfatizado
procedure PR_ENFATIZADO
      (p_texto     IN OUT VARCHAR2,        -- texto que se recibe y que se carga con las lineas
       p_sino      IN VARCHAR2 DEFAULT 'S' -- Prende o apaga
       ) IS
begin
   if nvl(p_sino,'S') = 'S' then -- se imprime la negrita
      p_texto := p_texto||chr(27)||'!1';
   else -- vuelve al normal
      p_texto := p_texto||chr(27)||'!'||chr(1);
   end if;
end PR_ENFATIZADO;

-- procedimiento para imprimir CONDENSADO
procedure PR_CONDENSADO
      (p_texto     IN OUT VARCHAR2,        -- texto que se recibe y que se carga con las lineas
       p_sino      IN VARCHAR2 DEFAULT 'S' -- Prende o apaga
       ) IS
begin
   if nvl(p_sino,'S') = 'S' then -- se imprime CONDENSADO
      p_texto := p_texto||chr(27)||chr(15);
   else -- vuelve al normal
      p_texto := p_texto||chr(27)||chr(18);
   end if;
end PR_CONDENSADO;

-- procedimiento para inicializar la impresora
procedure PR_INI_IMPRESORA
      (p_texto     IN OUT VARCHAR2        -- texto que se recibe y que se carga con las lineas
       ) IS
begin
   p_texto := p_texto||chr(27)||'@';
end PR_INI_IMPRESORA;

-- procedimiento para realizar el corte del papel
procedure PR_COR_PAPEL
      (p_texto     IN OUT VARCHAR2        -- texto que se recibe y que se carga con las lineas
       ) IS
begin
   p_texto := p_texto||chr(27)||chr(69);
end PR_COR_PAPEL;

-- proc. para setear la impresora, Este debe ser siempre el que inicia el texto de la impresion
function FU_SET_IMPRESORA
        (p_numero IN NUMBER,
         p_mensaje in VARCHAR2 DEFAULT null)
  return varchar2 is
v_texto varchar2(500);
begin
  if p_numero is not null then
     if p_numero not between 1 and 9 then
        raise_application_error(-20003, 'Debe definir la impresora solo con el Nro. del 1 al 9');
     end if;
     v_texto := '?' || p_numero; -- ? indica que el sgte dato es el nro de impresora

     if p_mensaje is not null then
        v_texto := v_texto || p_mensaje;
     end if;
     v_texto := v_texto || '?';  -- ? es el fin del seteo de impresora
  end if;

  return v_texto;
end;

procedure PR_SET_IMPRESORA
      (p_texto     IN OUT VARCHAR2,        -- texto que se recibe y que se carga con las lineas
       p_numero IN NUMBER,
       p_mensaje in VARCHAR2 DEFAULT null)
        IS
begin
   p_texto := p_texto||pag_imp.fu_set_impresora(p_numero, p_mensaje);

end PR_SET_IMPRESORA;

end PAG_IMP;
/

