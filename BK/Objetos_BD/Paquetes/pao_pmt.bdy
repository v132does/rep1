create or replace package body it.PAO_PMT is

g_msj_error varchar2(1000);

function fu_obt_msj_error return varchar2 is
begin
   return g_msj_error;
end fu_obt_msj_error;

/*Obtiene el Código de Mensaje del texto*/
function fu_obt_cod_msj_swift( p_texto in clob )
  return varchar2 is
begin
   --Se obtiene el cod_msj_swift, en caso de no existir solo retorna NULL
   return substr(regexp_substr(substr(p_texto, 0, 4000), '{2:\w[[:digit:]]{3}'), 5, 3);
end fu_obt_cod_msj_swift;

/*Obtiene el valor del Campo especificado del texto*/
function fu_obt_val_campo( p_texto in clob,
                           p_campo in sb_snp_campos.campo%type )
  return varchar2 is
begin
   --Obtiene el valor del TAG, en caso de no existir solo retorna NULL
   return replace(regexp_substr(p_texto, ':'||p_campo||':(.*)'), ':'||p_campo||':');
end fu_obt_val_campo;

/*Obtiene el Campo (tag) del texto*/
function fu_obt_campo( p_texto in clob )
  return varchar2 is
   v_campo sb_snp_campos.campo%type;
begin
   if substr(p_texto, 0, 3) = '{1:' then
      v_campo := 'CAB';
   elsif p_texto like '-}%' then
      v_campo := 'PIE';
   elsif instr(p_texto,'/STARTTIME/')  > 0 THEN
      /*MODIFICADO POR TRFS-1309, valida que la linea no sea un descriptico de fecha y hora
       dado que los minutos encerrados por : podia confundirse como un campo tag
      */
      v_campo := null;
   else
      --Obtiene el valor del TAG, en caso de no existir solo retorna NULL
      v_campo := replace(regexp_substr(p_texto, ':(.*?):',1,1, 'n'), ':');
   end if;

   return v_campo;

exception
   when others then
      return null;

end fu_obt_campo;

/*Obtiene la linea (cadena) a partir del texto y nro. de linea*/
function fu_obt_linea( p_texto       in clob,
                       p_nro_linea   in number,
                       p_delimitador in varchar2 default chr(10) )
  return clob is
  v_linea clob;
begin
   select linea
     into v_linea
     from (select rownum nro_linea,
                  column_value linea
             from table(fug_obt_tab_registro(replace(p_texto,chr(13)), p_delimitador))
            where column_value is not null) a
    where a.nro_linea = p_nro_linea;

   return v_linea;

exception
   when others then
     return null;
end fu_obt_linea;

/*Obtiene el Código y tipo de Mensaje del texto*/
function fu_obt_cod_mensaje ( p_texto in clob )
  return sb_snp_tip_mensajes.cod_mensaje%type is

   v_cod_msj_swift  varchar2(3);
   v_cod_mensaje    sb_snp_tip_mensajes.cod_mensaje%type;
   v_val_campo      varchar2(2000);

   cursor c_mensajes ( p_cod_msj_swift varchar2 ) is
      select a.cod_mensaje,
             substr( a.cod_mensaje, nvl( instr( a.cod_mensaje, '/' ), 0 ) + 1 ) tip_mensaje,
             a.tip_msj_campo
        from sb_snp_tip_mensajes a
       where substr( a.cod_mensaje, 3, 3 ) = p_cod_msj_swift
          or (substr( a.cod_mensaje, 4, 2 ) = substr( p_cod_msj_swift, 2, 2 )
              and a.cod_mensaje like '%n%');
begin

   v_cod_msj_swift := fu_obt_cod_msj_swift( fu_obt_linea(p_texto, 1) );

   if v_cod_msj_swift is null then
      raise_application_error(-20501, 'Código de mensaje no encontrado.');
   end if;

   for msj in c_mensajes ( v_cod_msj_swift ) loop
       if msj.tip_msj_campo is not null then
          v_val_campo := fu_obt_val_campo( p_texto, msj.tip_msj_campo );
          if msj.tip_mensaje = upper(pao_pmt.fu_obt_linea( v_val_campo, 1, '/' )) then
             v_cod_mensaje := msj.cod_mensaje;
          end if;
       else
          v_cod_mensaje := msj.cod_mensaje;
       end if;
   end loop;

   if v_cod_mensaje is null then
      raise_application_error(-20502, 'Tipo de mensaje no encontrado.');
   end if;

   return v_cod_mensaje;

end fu_obt_cod_mensaje;

/*Función que valida el formato Regex del Dato*/
function fu_val_formato( p_formato in sb_snp_formatos.formato%type,
                         p_valor   in sb_snp_mensajes_tmp.valor%type,
                         p_campo   in sb_snp_mensajes_tmp.campo%type )
   return varchar2 is
   r_sb_snp_formatos sb_snp_formatos%rowtype;
begin
   select *
     into r_sb_snp_formatos
     from sb_snp_formatos
    where formato = p_formato;
   if r_sb_snp_formatos.exp_regular is not null then
      if nvl(regexp_substr(p_valor, r_sb_snp_formatos.exp_regular), '*') != p_valor then
         return ' Error Formato Campo :'||p_campo||': '||p_valor||
            ' Formato esperado: '||r_sb_snp_formatos.descripcion||
            ' ('||r_sb_snp_formatos.formato||')';
      end if;
   end if;
   return null;
exception
  when no_data_found then
     return null;

end fu_val_formato;

/*Valida el Valor de Dato del campo*/
function fu_val_dato( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                      p_det_sql     in sb_snp_campos.det_sql_recibido%type,
                      p_valor       in sb_snp_mensajes_tmp.valor%type,
                      p_nro_detalle in sb_snp_mensajes_tmp.nro_detalle%type )
   return varchar2 is

   v_error varchar2(4000);

begin

   if trim(p_det_sql) is not null then
      execute immediate p_det_sql using in p_cod_mensaje, p_nro_detalle, p_valor, out v_error;
   end if;

   return v_error;

exception
   when others then
       return sqlerrm;

end fu_val_dato;

/*Obtiene el Valor por Defecto del Campo*/
function fu_obt_val_defecto( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                             p_det_sql     in sb_snp_campos.det_sql_recibido%type,
                             p_nro_detalle in sb_snp_mensajes_tmp.nro_detalle%type default 0 )
   return varchar2 is

   v_valor varchar2(4000);

begin

   if trim(p_det_sql) is not null then
      execute immediate p_det_sql using in p_cod_mensaje, p_nro_detalle, out v_valor;
   end if;

   return v_valor;

exception
   when others then
       return sqlerrm;

end fu_obt_val_defecto;

/*Obtiene el Campo XXa*/
function fu_obt_tag_campo( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                           p_det_sql     in sb_snp_campos.det_sql_recibido%type,
                           p_valor       in sb_snp_mensajes_tmp.valor%type )
   return varchar2 is

   v_valor varchar2(4000);

begin

   if trim(p_det_sql) is not null then
      execute immediate p_det_sql using in p_cod_mensaje, p_valor, out v_valor;
   end if;

   return v_valor;

exception
   when others then
       return sqlerrm;

end fu_obt_tag_campo;

/*Procesa el MT de Recepción*/
function fu_pro_mt_recibido( p_texto in clob )
  return varchar2 is

   r_sb_snp_tmp_mensajes sb_snp_mensajes_tmp%rowtype := null;
   v_cod_mensaje         sb_snp_tip_mensajes.cod_mensaje%type;
   v_can_lineas          number;
   v_det_campo           sb_snp_campos.campo%type;

begin
   begin
     --obtengo el mensaje, si no encuentra esquematizado igual se debe registrar en GE_SNP_MENSAJES
     v_cod_mensaje := pao_pmt.fu_obt_cod_mensaje(p_texto);
   exception
     when others then
       if sqlcode <= -20000 and
           upper( sqlerrm ) like '%MEN%NO%ENCONT%'
       then
          return '00|'||v_cod_mensaje||'|Error en la obtención del código de mensaje: '||sqlerrm;
       else
          raise;
       end if;
   end;
   --Obtengo el campo PK del Detalle
   select max(d.campo)
     into v_det_campo
     from sb_snp_campos d
    where d.cod_mensaje = v_cod_mensaje
      and d.orden = (select min(orden)
                       from sb_snp_campos
                      where cod_mensaje = d.cod_mensaje
                        and ind_detalle = d.ind_detalle)
      and d.ind_detalle = 'S';
   --Se cuentan la cantidad de líneas para el recorrido
   select count(*)
     into v_can_lineas
     from table(fug_obt_tab_registro(replace(p_texto, chr(13)), chr(10)));
   --Se elimina los datos de la tabla temporal para el tipo de mensaje
   delete sb_snp_mensajes_tmp where cod_mensaje = v_cod_mensaje;
   --Grabo línea por línea
   for i in 1..v_can_lineas loop
      r_sb_snp_tmp_mensajes.cod_mensaje := v_cod_mensaje;
      r_sb_snp_tmp_mensajes.orden := i;
      r_sb_snp_tmp_mensajes.valor := trim(fu_obt_linea(p_texto, r_sb_snp_tmp_mensajes.orden));
      r_sb_snp_tmp_mensajes.campo := nvl(fu_obt_campo(r_sb_snp_tmp_mensajes.valor), r_sb_snp_tmp_mensajes.campo);
      if r_sb_snp_tmp_mensajes.campo = fu_obt_campo(r_sb_snp_tmp_mensajes.valor) then
         r_sb_snp_tmp_mensajes.nro_linea := 1;
         if nvl(v_det_campo, '*') = r_sb_snp_tmp_mensajes.campo then
            r_sb_snp_tmp_mensajes.nro_detalle := nvl(r_sb_snp_tmp_mensajes.nro_detalle, 0) + 1;
         end if;
      else
         r_sb_snp_tmp_mensajes.nro_linea := r_sb_snp_tmp_mensajes.nro_linea + 1;
      end if;
      r_sb_snp_tmp_mensajes.valor := trim(replace(r_sb_snp_tmp_mensajes.valor, ':'||r_sb_snp_tmp_mensajes.campo||':'));
      insert into sb_snp_mensajes_tmp values r_sb_snp_tmp_mensajes;
   end loop;

   --Se verifica el esquema
   r_sb_snp_tmp_mensajes.err_formato := fu_ver_esquema(v_cod_mensaje, 'N');
   if trim(r_sb_snp_tmp_mensajes.err_formato) is not null then
      --Si hubieron errores retorna
      return '00|'||v_cod_mensaje||'|Error en el formato: '||r_sb_snp_tmp_mensajes.err_formato;
   end if;

   --Procesa la Ejecución dinámica con la función parametrizada
   declare
      v_obj_proceso   sb_snp_tip_mensajes.obj_proceso%type;
      v_ret_funcion   varchar2(1000);
      v_sql           varchar2(32767);
    begin
       --Obtengo la función
       select b.obj_proceso
         into v_obj_proceso
         from sb_snp_tip_mensajes b
        where b.cod_mensaje = r_sb_snp_tmp_mensajes.cod_mensaje;
       if v_obj_proceso is null then
          return '00|'||v_cod_mensaje||'|Error al buscar el objeto a procesar: No hay Función de proceso definida para '||r_sb_snp_tmp_mensajes.cod_mensaje;
       else
          v_sql := 'BEGIN :b := '||v_obj_proceso||'('||chr(39)||replace(replace(p_texto, chr(39), chr(39)||chr(39)),chr(13)||chr(10),'*')||chr(39)||'); END;';
          EXECUTE IMMEDIATE v_sql USING OUT v_ret_funcion;
       end if;
       --Retorno el mensaje de la lógica de negocios
       return v_ret_funcion;
    exception
       when no_data_found then
          return '00|'||v_cod_mensaje||'|Error al buscar el objeto a procesar(2): No hay Función de proceso definida para '||r_sb_snp_tmp_mensajes.cod_mensaje;
       when others then
          return '00|'||v_cod_mensaje||'|Error al ejecutar el objeto '||v_obj_proceso||': '||sqlerrm;
    end;

exception
   when others then
      return '00|'||v_cod_mensaje||'Error al procesar el MT recibido: '||sqlerrm;

end fu_pro_mt_recibido;

/*Obtiene la Prioridad a partir de la Cabecera*/
function fu_obt_prioridad( p_cadena in varchar2 ) return number is

begin

   return to_number(replace(regexp_substr(p_cadena,
                                   '{3:{113:([[:alnum:]]+\.?){3,4}/?') , '{3:{113:'));

end fu_obt_prioridad;

/*Obtiene Monto, Fecha o Moneda de la Cadena*/
function fu_obt_tip_valor( p_cadena in varchar2,
                           p_tipo   in varchar2 ) return varchar2 is
  v_valor varchar2(30);
begin
   pre_cam_for_numerico(',.');
   if p_tipo = 'TIP' then --Tipo
      /*Solo Debito (D) o Credito (C)*/
      v_valor := regexp_substr(p_cadena, '^(D|C|){1}');
   elsif p_tipo = 'FEC' then --fecha
      v_valor := to_date(replace(regexp_substr(p_cadena, '^(D|C|){1}\d{6}'), regexp_substr(p_cadena, '^(D|C|){1}')), 'YYMMDD');
   elsif p_tipo = 'MON' then --Moneda
      v_valor := regexp_substr(p_cadena, '[A-Z]{3}');
   elsif p_tipo = 'MTO' then --Moneda
      v_valor := replace(regexp_substr(p_cadena, '[A-Z]{3}\d+,(\w+){0,}'), regexp_substr(p_cadena, '[A-Z]{3}'));
   end if;

   return v_valor;

exception
   when others then
       return null;

end fu_obt_tip_valor;

/*Obtiene valor de instacia por delimitador de una cadena*/
function fu_obt_val_delimitador(p_cadena    in varchar2,
                                p_posicion  in number) return varchar2 is
  v_retorno varchar2(200);
begin
  select linea
    into v_retorno
    from ( select rownum nro_linea,
                  column_value linea
             from table(fug_obt_tab_registro(p_cadena, '/'))
            where column_value is not null )
    where nro_linea = p_posicion;
  return v_retorno;
exception
  when others then
     return p_cadena;
end fu_obt_val_delimitador;

/*Inserta los datos de salida en la tabla SB_SNP_MENSAJE_TMP*/
procedure pr_ins_sb_snp_mensajes_tmp( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                                      p_campo       in sb_snp_mensajes_tmp.campo%type,
                                      p_valor       in sb_snp_mensajes_tmp.valor%type,
                                      p_nro_detalle in sb_snp_mensajes_tmp.nro_detalle%type default 0) is

   v_det_sql    sb_snp_mensajes_tmp.det_sql%type;
   v_err_validacion sb_snp_mensajes_tmp.err_validacion%type;

begin

   --si es la cabecera es uno nuevo..
   if p_campo = 'CAB' then
      delete sb_snp_mensajes_tmp a
       where a.cod_mensaje = p_cod_mensaje;
   end if;

   insert into sb_snp_mensajes_tmp
     ( cod_mensaje, orden, campo, valor, nro_linea, nro_detalle, det_sql, err_validacion )
   values
     ( p_cod_mensaje,
       ( select nvl( max( orden ), 0 ) + 1 --Hallo el orden
           from sb_snp_mensajes_tmp
          where cod_mensaje = p_cod_mensaje
       ),
       p_campo,
       p_valor,
       ( select nvl( max( nro_linea ), 0 ) + 1 --Hallo el nro. de linea
           from sb_snp_mensajes_tmp
          where cod_mensaje = p_cod_mensaje
            and campo = p_campo
            and nro_detalle = p_nro_detalle
       ),
       p_nro_detalle,
       v_det_sql,
       v_err_validacion
     );

end pr_ins_sb_snp_mensajes_tmp;

/*Inserta los datos de salida en la tabla SB_SNP_MENSAJE_TMP y valida el Dato ingresado*/
procedure pr_ins_sb_snp_mensajes_tmp( p_cod_mensaje    in sb_snp_mensajes_tmp.cod_mensaje%type,
                                      p_campo          in sb_snp_mensajes_tmp.campo%type,
                                      p_valor          in sb_snp_mensajes_tmp.valor%type,
                                      p_nro_detalle    in sb_snp_mensajes_tmp.nro_detalle%type default 0,
                                      p_err_validacion in out varchar2 ) is

   v_det_sql        sb_snp_mensajes_tmp.det_sql%type;
   v_err_validacion sb_snp_mensajes_tmp.err_validacion%type;

begin

   --si es la cabecera es uno nuevo..
   if p_campo = 'CAB' then
      delete sb_snp_mensajes_tmp a
       where a.cod_mensaje = p_cod_mensaje;
   end if;

   begin
      SELECT a.det_sql_enviado
        INTO v_det_sql
        FROM sb_snp_campos a
       WHERE a.cod_mensaje = p_cod_mensaje
         AND a.campo = p_campo
         AND a.ind_detalle = decode(p_nro_detalle, 0, 'N', 'S')
         AND a.orden = (SELECT MIN(orden)
                          FROM (SELECT rownum cc,
                                       b.orden
                                  FROM sb_snp_campos b
                                 WHERE b.cod_mensaje = p_cod_mensaje
                                   AND b.campo = p_campo
                                 ORDER BY b.orden) xx
                         WHERE xx.cc > (SELECT COUNT(*)
                                          FROM sb_snp_mensajes_tmp j
                                         WHERE j.cod_mensaje = p_cod_mensaje
                                           AND j.campo = p_campo
                                           AND j.nro_detalle = p_nro_detalle));
   exception
       when no_data_found then
          null;
       when too_many_rows then
          null;
   end;

   v_err_validacion := fu_val_dato(p_cod_mensaje, v_det_sql, p_valor, p_nro_detalle );
   if v_err_validacion is not null then --Si hubo errores concateno
      p_err_validacion := substr(p_err_validacion||'|'||v_err_validacion, 1, 4000);
   end if;

   insert into sb_snp_mensajes_tmp
     ( cod_mensaje, orden, campo, valor, nro_linea, nro_detalle, det_sql, err_validacion )
   values
     ( p_cod_mensaje,
       ( select nvl( max( orden ), 0 ) + 1 --Hallo el orden
           from sb_snp_mensajes_tmp
          where cod_mensaje = p_cod_mensaje
       ),
       p_campo,
       p_valor,
       ( select nvl( max( nro_linea ), 0 ) + 1 --Hallo el nro. de linea
           from sb_snp_mensajes_tmp
          where cod_mensaje = p_cod_mensaje
            and campo = p_campo
            and nro_detalle = p_nro_detalle
       ),
       p_nro_detalle,
       v_det_sql,
       v_err_validacion
     );

end pr_ins_sb_snp_mensajes_tmp;

/*Procesa el MT de Envío*/
procedure pr_pro_mt_enviado( p_cod_mensaje in  sb_snp_tip_mensajes.cod_mensaje%type,
                             p_texto       out clob,
                             p_nro_detalle in  sb_snp_mensajes_tmp.nro_detalle%type default null ) is

   v_campo           sb_snp_campos.campo%type;
   v_tag             varchar2(6);
   v_can_err_formato number := 0;
   v_err_esquema     varchar2(120);

   cursor c_mensaje is
      select *
        from sb_snp_mensajes_tmp c
       where c.cod_mensaje = p_cod_mensaje
         and c.nro_detalle = nvl(p_nro_detalle, c.nro_detalle)
         and (c.valor is not null or c.campo = '77E')
       order by c.orden;

begin

   update sb_snp_mensajes_tmp g
      set g.campo = nvl((select max(campo)
                       from sb_snp_mensajes_tmp h
                      where substr(h.campo, 0,2) = substr(g.campo, 0,2)
                        and h.campo not like '%a'), g.campo)
    where g.campo like '%a'
    and g.cod_mensaje = p_cod_mensaje;

   g_msj_error := null;
   v_campo     := null;

   if p_nro_detalle is null then
      --Se verifica esquema
      v_err_esquema := fu_ver_esquema(p_cod_mensaje, 'S');
      if v_err_esquema is not null then
         raise_application_error(-20001, v_err_esquema);
      end if;
   end if;
   --Se recorre el mensaje para armar el texto del MT.
   for msj in c_mensaje loop
      --Se valida si hay errores de formato.
      if msj.err_formato is not null then
         v_can_err_formato := v_can_err_formato + 1;
         g_msj_error := 'Se encontraron ' || v_can_err_formato || ' Errores de Formato';
      end if;

      --Si el campo es Cabecera o Pie o son líneas que pertenece al TAG se concatena directamente sin el Tag.
      if msj.campo in ('CAB', 'PIE')
        or msj.campo is null
        or nvl(v_campo, '*') = msj.campo then
         v_tag := null;
      else
         v_campo := msj.campo;
         v_tag := ':'||msj.campo||':';
      end if;
      --Se concatenan los valores
      if p_texto is null then
         p_texto := v_tag||msj.valor;
      else
         p_texto := p_texto||chr(10)||v_tag||msj.valor;
      end if;
   end loop;

end pr_pro_mt_enviado;

/*Obtiene los valores del MT en proceso*/
function fu_obt_val_mt_proceso ( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                                 p_campo       in sb_snp_mensajes_tmp.campo%type,
                                 p_nro_linea   in sb_snp_mensajes_tmp.nro_linea%type default null,
                                 p_nro_detalle in varchar2 default 0 )
return varchar2 is

   v_valor varchar2(4000);

   cursor c_valor is
      select a.valor
        from sb_snp_mensajes_tmp a
       where a.cod_mensaje = p_cod_mensaje
         and ((substr(p_campo, 3, 1) = 'a' and substr(a.campo, 1, 2) = substr(p_campo, 1, 2))
          or a.campo = p_campo)
         and a.nro_detalle = nvl(p_nro_detalle, 0)
         and a.nro_linea = nvl(p_nro_linea, a.nro_linea)
       order by a.nro_linea;

begin

   for val in c_valor loop
      v_valor := v_valor || val.valor || chr(10);
   end loop;

   if v_valor is not null then
      v_valor := substr(v_valor, 0, length(v_valor) -1);
   end if;

   return v_valor;

end fu_obt_val_mt_proceso;

/*Obtiene los valores del MT en proceso, y Valida los datos con el DET_SQL cargado*/
function fu_obt_val_mt_proceso ( p_cod_mensaje    in sb_snp_mensajes_tmp.cod_mensaje%type,
                                 p_campo          in sb_snp_mensajes_tmp.campo%type,
                                 p_nro_linea      in sb_snp_mensajes_tmp.nro_linea%type default null,
                                 p_nro_detalle    in varchar2 default 0,
                                 p_err_validacion in out varchar2 )
return varchar2 is

   v_err_validacion varchar2(300);
   v_valor          varchar2(4000);

   cursor c_valor is
      select a.valor,
             a.det_sql
        from sb_snp_mensajes_tmp a
       where a.cod_mensaje = p_cod_mensaje
         and ((substr(p_campo, 3, 1) = 'a' and substr(a.campo, 1, 2) = substr(p_campo, 1, 2))
          or a.campo = p_campo)
         and a.nro_detalle = nvl(p_nro_detalle, 0)
         and a.nro_linea = nvl(p_nro_linea, a.nro_linea)
       order by a.nro_linea
      for update of a.err_validacion;

begin

   for val in c_valor loop
      v_valor := v_valor || val.valor || chr(10);
      begin
         v_err_validacion := fu_val_dato(p_cod_mensaje, val.det_sql, val.valor, p_nro_detalle);
         if v_err_validacion is not null then
            update sb_snp_mensajes_tmp
               set err_validacion = v_err_validacion
             where current of c_valor;

            if v_err_validacion is not null then --Si hubo errores concateno
               p_err_validacion := substr(p_err_validacion||chr(10)||v_err_validacion, 1, 4000);
            end if;
         end if;
      exception
         when others then
            raise_application_error(-20506, 'Error al Validar Datos '||sqlerrm);
      end;
   end loop;

   if v_valor is not null then
      v_valor := substr(v_valor, 0, length(v_valor) -1);
   end if;

   return v_valor;

end fu_obt_val_mt_proceso;

/*Forma la cadena del Swift en proceso*/
function fu_obt_msj_swift( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                           p_nro_detalle in sb_snp_mensajes_tmp.nro_detalle%type default null )
   return clob is

   v_mensaje clob;
   v_campo   sb_snp_mensajes_tmp.campo%type;

   cursor c_mensaje is
     select a.campo,
            a.valor
       from sb_snp_mensajes_tmp a
      where a.cod_mensaje = p_cod_mensaje
        and a.nro_detalle = nvl(p_nro_detalle, a.nro_detalle)
      order by a.orden;

begin

   for msj in c_mensaje loop
      if nvl(v_campo, '*') != msj.campo then
         v_mensaje := v_mensaje||chr(10)||':'||msj.campo||':'||msj.valor;
         v_campo := msj.campo;
      else
         v_mensaje := v_mensaje||chr(10)||msj.valor;
      end if;
   end loop;

   return v_mensaje;

end fu_obt_msj_swift;

/*Inicializa la Tabla Temporal con el MT esquematizado para generar un MT*/
procedure pr_ini_sb_snp_mensajes_tmp( p_cod_mensaje   in sb_snp_tip_mensajes.cod_mensaje%type,
                                      p_cod_msj_swift in number,
                                      p_prioridad     in number,
                                      p_can_detalle   in number ) is

   v_orden           sb_snp_mensajes.orden%type := 1;
   v_valor           sb_snp_mensajes_tmp.valor%type;
   v_des_campo       sb_snp_mensajes_tmp.descripcion%type;
   v_can_campo       number := 1;

   cursor c_esquema is
      select c.campo,
             c.cod_mensaje,
             c.orden,
             c.descripcion,
             c.ind_requerido,
             c.ind_detalle,
             c.can_max_lineas,
             c.det_sql_val_defecto
        from sb_snp_campos c
       where c.cod_mensaje = p_cod_mensaje
       order by c.orden;

begin

    delete from sb_snp_mensajes_tmp;

    for esq in c_esquema loop
       v_valor := fu_obt_val_defecto(p_cod_mensaje, esq.det_sql_val_defecto, 0);

       /*Validcion cabecera*/
       if esq.campo = 'CAB' then
          if p_cod_msj_swift is null
            and esq.cod_mensaje like '%n%' then
             raise_application_error(-20507, 'Debe especificar el Código Swift');
          elsif p_cod_msj_swift is null then
             v_valor := replace(v_valor, '&COD_MSJ_SWIFT', substr(esq.cod_mensaje, 3, 3));
          else
             v_valor := replace(v_valor, '&COD_MSJ_SWIFT', p_cod_msj_swift);
          end if;
          v_valor := replace(v_valor, '&PRIORIDAD', lpad(to_char(p_prioridad),4,'0'));
       end if;

       for i in 1..esq.can_max_lineas loop
          if v_des_campo is null then
             v_des_campo := esq.descripcion;
          elsif v_des_campo != esq.descripcion then
             v_des_campo := esq.descripcion;
             v_can_campo := 1;
          else
             v_can_campo := v_can_campo + 1;
          end if;

          insert into sb_snp_mensajes_tmp
            (cod_mensaje, valor, orden, campo, descripcion, ind_requerido, nro_linea, nro_detalle, det_sql)
          values
            (esq.cod_mensaje, v_valor, v_orden, esq.campo, esq.descripcion, decode(i, 1, esq.ind_requerido, 'N'), v_can_campo, decode(esq.ind_detalle, 'N', 0, 1), esq.det_sql_val_defecto);
          v_orden := v_orden + 1;
       end loop;
    end loop;
    --Carga de Detalles por cantidad (p_can_detalle)
    if p_can_detalle > 1 then
       declare
          v_max_orden sb_snp_mensajes_tmp.orden%type;
          v_orden     sb_snp_mensajes_tmp.orden%type;

          cursor c_detalle is
             select cod_mensaje, valor, orden, campo, descripcion, ind_requerido, nro_linea, nro_detalle, det_sql
               from sb_snp_mensajes_tmp a
              where a.cod_mensaje = p_cod_mensaje
                and a.nro_detalle = 1
              order by orden;

          cursor c_pie is
             select c.orden
               from sb_snp_mensajes_tmp c
              where c.orden > v_max_orden
                and c.nro_detalle = 0
                for update of c.orden;
       begin
          select max(orden)
            into v_max_orden
            from sb_snp_mensajes_tmp b
           where b.cod_mensaje = p_cod_mensaje
             and b.nro_detalle = 1;

          v_orden := v_max_orden;
          --Se insertan detalles
          for i in 2..p_can_detalle loop
             for det in c_detalle loop
                v_orden := v_orden + 1;
                insert into sb_snp_mensajes_tmp
                  (cod_mensaje, valor, orden, campo, descripcion, ind_requerido, nro_linea, nro_detalle, det_sql)
                values
                  (det.cod_mensaje, det.valor, v_orden, det.campo, det.descripcion, det.ind_requerido, det.nro_linea, i, det.det_sql);
             end loop;
          end loop;
          --Se corre el orden del pie
          for d in c_pie loop
             v_orden := v_orden + 1;
             update sb_snp_mensajes_tmp
                set orden = v_orden
              where current of c_pie;
          end loop;
       exception
           when others then
               null;
       end;
    end if;

end pr_ini_sb_snp_mensajes_tmp;

/*Función que verifica los Datos cargados en la tabla temporal contra el esquema*/
function fu_ver_esquema( p_cod_mensaje in sb_snp_mensajes_tmp.cod_mensaje%type,
                         p_ind_envio   in varchar2 )
 return varchar2 is

  v_det_campo           sb_snp_campos.campo%type;
  v_tag_campo           sb_snp_campos.campo%type;
  v_can_lineas          number := 0;
  v_row_count           number;
  v_ult_orden           number;

  cursor c_esquema (p_ind_detalle in sb_snp_campos.ind_detalle%type) is
     select a.campo,
            a.cod_mensaje,
            a.descripcion,
            a.can_max_lineas,
            a.ind_requerido,
            a.ind_detalle,
            a.formato,
            a.det_sql_recibido,
            a.det_sql_campo,
            ( select count(*)
                from sb_snp_campos b
               where b.cod_mensaje = a.cod_mensaje
                 and b.campo = a.campo
            ) can_campos
       from sb_snp_campos a
      where a.cod_mensaje = p_cod_mensaje
        and a.ind_detalle = p_ind_detalle
      order by a.orden;

  begin
     --Nulo los indicadores.
     update sb_snp_mensajes_tmp a
        set a.ind_requerido = null,
            a.err_formato = null
      where a.cod_mensaje = p_cod_mensaje;

     --Obtengo el campo PK del Detalle
     select max(d.campo)
       into v_det_campo
       from sb_snp_campos d
      where d.cod_mensaje = p_cod_mensaje
        and d.orden = (select min(orden)
                         from sb_snp_campos
                        where cod_mensaje = d.cod_mensaje
                          and ind_detalle = d.ind_detalle)
        and d.ind_detalle = 'S';
     --Si existe veo la cantidad
     if v_det_campo is not null then
        select count(*)
          into v_can_lineas
          from sb_snp_mensajes_tmp a
         where a.cod_mensaje = p_cod_mensaje
           and a.campo = v_det_campo
           and a.nro_linea = 1;
     end if;
     --Giro por la cantidad de detalles encontrado
     for det in 1..v_can_lineas loop
        --Giro por el esquema esperado para el detalle
        for esq in c_esquema ('S') loop
           if v_det_campo = esq.campo or det = v_can_lineas then
              v_ult_orden := 99999;
           else
              select min(orden)
                into v_ult_orden
                from sb_snp_mensajes_tmp s
               where s.cod_mensaje = esq.cod_mensaje
                 and s.campo = v_det_campo
                 and s.ind_requerido is null;
           end if;

           /*Grabo del esquema:
             La descripción del campo
             Indicador de campo requerido
             Indicador de detalle
             Valído formato con el valor y el REGEX obtenido del esquema
           */
           update sb_snp_mensajes_tmp e
              set e.descripcion    = nvl(e.descripcion, esq.descripcion),
                  e.ind_requerido  = esq.ind_requerido,
                  e.nro_detalle    = nvl(e.nro_detalle, det),
                  e.err_formato    = fu_val_formato(esq.formato, e.valor, esq.campo),
                  e.det_sql        = esq.det_sql_recibido
            where e.cod_mensaje = esq.cod_mensaje
              and e.ind_requerido is null
              and nvl(e.valor, 'X') = case
                                         when p_ind_envio = 'S' and esq.formato is not null then
                                            nvl(e.valor, 'Y')
                                         else
                                            nvl(e.valor, 'X')
                                         end
              --Campo comodín, si es 59a cualquier 59X es válido
              and ((substr(esq.campo, 3, 1) = 'a' and substr(e.campo, 1, 2) = substr(esq.campo, 1, 2))
                or e.campo = esq.campo)
              --Se limita el orden hasta el último Tag del Batch
              and e.orden < v_ult_orden
              /*Si la cantidad de lineas permitidas es mayor a 1 hacer update a todos, no solo el
              No solo el primero que encuentre*/
              and ((esq.can_max_lineas > 1
                  and e.orden between (select min(orden)
                                         from sb_snp_mensajes_tmp b
                                        where b.cod_mensaje = esq.cod_mensaje
                                          and b.campo = e.campo
                                          and b.ind_requerido is null)
                                        and
                                      (select nvl(min(orden), 0) + esq.can_max_lineas
                                         from sb_snp_mensajes_tmp b
                                        where b.cod_mensaje = esq.cod_mensaje
                                          and b.campo = e.campo
                                          and b.ind_requerido is null))
                  or
                   (esq.can_max_lineas = 1
                    and e.orden = (select min(orden)
                                     from sb_snp_mensajes_tmp b
                                    where b.cod_mensaje = esq.cod_mensaje
                                      and b.campo = e.campo
                                      and b.ind_requerido is null)));

            v_row_count := sql%rowcount;

            if v_row_count = 0
              and esq.ind_requerido = 'S'then
               return 'Campo requerido :'||esq.campo||': '||esq.descripcion||' No encontrado (Det:'||det||')';
            end if;
            --Arreglo campos 2da linea
            if esq.can_campos > 1
               and p_ind_envio = 'N' then
               update sb_snp_mensajes_tmp e
                  set e.descripcion = (select max(descripcion)
                                         from sb_snp_campos f
                                        where f.cod_mensaje = e.cod_mensaje
                                          and f.campo = e.campo
                                          and f.descripcion != e.descripcion),
                      e.err_formato = fu_val_formato((select max(f.formato)
                                                        from sb_snp_campos f
                                                       where f.cod_mensaje = e.cod_mensaje
                                                         and f.campo = e.campo
                                                         and f.descripcion != e.descripcion) , e.valor, e.campo)
                where e.cod_mensaje = esq.cod_mensaje
                  and e.campo = esq.campo
                  and e.err_formato is not null
                  and esq.ind_requerido = 'N'
                  and e.nro_linea = 1;
            end if;
            --Update campo
            if p_ind_envio = 'S'
              and esq.det_sql_campo is not null then

               select fu_obt_tag_campo(esq.cod_mensaje, esq.det_sql_campo, max(e.valor))
                 into v_tag_campo
                 from sb_snp_mensajes_tmp e
                where e.cod_mensaje = esq.cod_mensaje
                  and substr(e.campo, 1, 2) = substr(esq.campo, 1, 2)
                  and nvl(e.descripcion, esq.descripcion) = esq.descripcion;

               update sb_snp_mensajes_tmp e
                  set e.campo = nvl(v_tag_campo, e.campo)
                where e.cod_mensaje = esq.cod_mensaje
                  and substr(esq.campo, 3, 1) = 'a'
                  and substr(e.campo, 1, 2) = substr(esq.campo, 1, 2);
            end if;
         end loop;
      end loop;
     v_can_lineas := 0;
     --Giro por el esquema esperado para los campos que no son detalle
     for esq in c_esquema ('N') loop
        if trim(esq.campo) is null then
           v_can_lineas := v_can_lineas + 1;
           --Si es un Campo en Blanco actualiza todos los que estén fuera de esquema
           update sb_snp_mensajes_tmp e
              set e.descripcion    = nvl(e.descripcion, esq.descripcion),
                  e.ind_requerido  = esq.ind_requerido,
                  e.nro_detalle    = 0,
                  e.err_formato    = fu_val_formato(esq.formato, e.valor, esq.campo),
                  e.det_sql        = esq.det_sql_recibido
            where e.cod_mensaje = esq.cod_mensaje
              and e.ind_requerido is null
              and (e.campo not in (select campo from sb_snp_campos where cod_mensaje = esq.cod_mensaje)
               or trim(e.campo) is null);
        else
           update sb_snp_mensajes_tmp e
              set e.descripcion    = nvl(e.descripcion, esq.descripcion),
                  e.ind_requerido  = esq.ind_requerido,
                  e.nro_detalle    = 0,
                  e.err_formato    = fu_val_formato(esq.formato, e.valor, esq.campo),
                  e.det_sql        = esq.det_sql_recibido
            where e.cod_mensaje = esq.cod_mensaje
              and e.ind_requerido is null
              and nvl(e.valor, 'X') = case
                           when p_ind_envio = 'S' and esq.formato is not null then
                              nvl(e.valor, 'Y')
                           else
                              nvl(e.valor, 'X')
                           end
              /*Campo comodín, si es 59a cualquier 59X es válido*/
              and ((substr(esq.campo, 3, 1) = 'a' and substr(e.campo, 1, 2) = substr(esq.campo, 1, 2))
               or e.campo = esq.campo)
              /*Si la cantidad de lineas permitidas es mayor a 1 hacer update a todos, no solo el
                No solo el primero que encuentre*/
              and ((esq.can_max_lineas > 1
                   and e.orden between  (select min(orden)
                                           from sb_snp_mensajes_tmp b
                                          where b.cod_mensaje = esq.cod_mensaje
                                            and b.campo = e.campo
                                            and b.ind_requerido is null)
                                          and
                                        (select nvl(min(orden), 0) + esq.can_max_lineas
                                           from sb_snp_mensajes_tmp b
                                          where b.cod_mensaje = esq.cod_mensaje
                                            and b.campo = e.campo
                                            and b.ind_requerido is null))
                    or
                    (esq.can_max_lineas = 1
                     and e.orden = (select min(orden)
                                      from sb_snp_mensajes_tmp b
                                     where b.cod_mensaje = esq.cod_mensaje
                                       and b.campo = e.campo
                                       and b.ind_requerido is null)));
        end if;

        v_row_count := sql%rowcount;

        if v_row_count = 0
          and esq.ind_requerido = 'S' then
           update sb_snp_mensajes_tmp e
              set e.descripcion = esq.descripcion,
                  e.err_formato = fu_val_formato(esq.formato, e.valor, esq.campo)
            where e.cod_mensaje = esq.cod_mensaje
              and e.campo = esq.campo
              and e.ind_requerido = 'N'
              and e.nro_detalle = 0;

           v_row_count := sql%rowcount;
           if v_row_count = 0 then
              return 'Campo requerido :'||esq.campo||': '||esq.descripcion||' No encontrado';
           end if;
        end if;

        if v_row_count > esq.can_max_lineas then
           return 'Cantidad de máxima de lineas excedida para el Campo '||esq.campo||' Máximo: '||esq.can_max_lineas||' Encontradas: '||sql%rowcount;
        end if;

        --Arreglo campos 2da linea
        if esq.can_campos > 1
           and p_ind_envio = 'N' then
           update sb_snp_mensajes_tmp e
              set e.descripcion = (select max(descripcion)
                                     from sb_snp_campos f
                                    where f.cod_mensaje = e.cod_mensaje
                                      and f.campo = e.campo
                                      and f.descripcion != e.descripcion),
                  e.err_formato = fu_val_formato((select max(f.formato)
                                                    from sb_snp_campos f
                                                   where f.cod_mensaje = e.cod_mensaje
                                                     and f.campo = e.campo
                                                     and f.descripcion != e.descripcion) , e.valor, e.campo)
            where e.cod_mensaje = esq.cod_mensaje
              and e.campo = esq.campo
              and e.err_formato is not null
              and esq.ind_requerido = 'N'
              and e.nro_linea = 1;
        end if;
        --Update campo
        if p_ind_envio = 'S'
          and esq.det_sql_campo is not null then

           select fu_obt_tag_campo(esq.cod_mensaje, esq.det_sql_campo, max(e.valor))
             into v_tag_campo
             from sb_snp_mensajes_tmp e
            where e.cod_mensaje = esq.cod_mensaje
              and substr(e.campo, 1, 2) = substr(esq.campo, 1, 2)
              and nvl(e.descripcion, esq.descripcion) = esq.descripcion;

           update sb_snp_mensajes_tmp e
              set e.campo = nvl(v_tag_campo, e.campo)
            where e.cod_mensaje = esq.cod_mensaje
              and substr(esq.campo, 3, 1) = 'a'
              and substr(e.campo, 1, 2) = substr(esq.campo, 1, 2);
        end if;
     end loop;

     /*Arreglo para lo campos "nulos"*/
     for noc in (select *
                   from sb_snp_campos j
                  where j.cod_mensaje = p_cod_mensaje
                    and trim(j.campo) is null) loop

           update sb_snp_mensajes_tmp e
              set e.descripcion    = noc.descripcion,
                  e.ind_requerido  = noc.ind_requerido,
                  e.nro_detalle    = decode(noc.ind_detalle, 'N', 0, e.nro_detalle),
                  e.campo          = ' ',
                  e.err_formato    = fu_val_formato(noc.formato, e.valor, noc.campo),
                  e.det_sql        = noc.det_sql_recibido
            where e.cod_mensaje = noc.cod_mensaje
              and e.nro_detalle is null
              and ((noc.can_max_lineas > 1
              and e.orden between  (select min(orden)
                                      from sb_snp_mensajes_tmp b
                                     where b.cod_mensaje = noc.cod_mensaje
                                       and b.campo = e.campo
                                       and b.ind_requerido is null)
                                       and
                                      (select nvl(min(orden), 0) + noc.can_max_lineas
                                       from sb_snp_mensajes_tmp b
                                      where b.cod_mensaje = noc.cod_mensaje
                                        and b.campo = e.campo
                                        and b.ind_requerido is null))
                or
                (noc.can_max_lineas = 1
                 and e.orden = (select min(orden)
                                  from sb_snp_mensajes_tmp b
                                 where b.cod_mensaje = noc.cod_mensaje
                                   and b.campo = e.campo
                                   and b.ind_requerido is null)));

     end loop;

     v_can_lineas := 1;
     for upd in (select rowid
                   from sb_snp_mensajes_tmp a
                  where a.cod_mensaje = p_cod_mensaje
                    and trim(a.campo) is null
                  order by orden) loop
        update sb_snp_mensajes_tmp
           set nro_linea = v_can_lineas
         where rowid = upd.rowid;
        v_can_lineas := v_can_lineas + 1;
     end loop;

     --Si no hubo errores.
     return null;

end fu_ver_esquema;

end PAO_PMT;
/

