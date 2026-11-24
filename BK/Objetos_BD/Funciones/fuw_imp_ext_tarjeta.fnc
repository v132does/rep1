CREATE OR REPLACE FUNCTION IT."FUW_IMP_EXT_TARJETA"(P_NRO_TARJETA in varchar2, --nro de cuenta o tarjeta
                                                 P_MES         in number,
                                                 P_ANHO        in number,
                                                 P_VER_TODOS   in varchar2 default 'T') -- N/S/T Ninguna, Solo sus mov. Todos los movimientos.
 return clob is

  --devuelve los datos del extracto en formato html para imprimir el comprobante en la web
  --
  v_tar_adicional       number := 0;
  v_cupon               varchar2(50) := '12345';
  v_transaccionEspecial number := 0;
  v_nro_cuenta          ge_cuentas.nro_cuenta%type;
  v_retorno             clob := '';
  v_error               varchar2(1000);
  v_fecha               date := to_date('01/' || ltrim(to_Char(p_mes, '00')) || '/' ||
                                        ltrim(to_char(p_anho, '0000')),
                                        'dd/mm/yyyy');
  v_nombre              varchar2(50);
  v_nro_tarjeta         ta_tarjetas.nro_tarjeta%type;
  v_nro_tarjeta_ant     ta_tarjetas.nro_tarjeta%type;
  v_fec_actual          date := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_direccion           ba_direcciones.direccion%type;
  v_localidad           ba_ciudades.descripcion%type;
  v_cod_persona         ba_personas.cod_persona%type;
  v_tar_principal       number := 0;

  -- devuelve el campo date formateado
  function lf_for_fecha(p_dato in date) return char is
  begin
    return rpad(nvl(to_char(p_dato, 'dd/mm/yyyy'), ' '), 10, ' ');
  end;

  -- devuelve el campo monto formateado
  function lf_for_monto(p_dato in number) return varchar2 is
  begin
    return replace(replace(replace(ltrim(to_char(nvl(p_dato, 0),
                                                 '99,999,999,999,999.99')),
                                   '.',
                                   '#'),
                           ',',
                           '.'),
                   '#',
                   ',');
  end;

  procedure lp_obt_direccion(p_nro_Cuenta in varchar2) is

  begin
    --
    select cod_persona
      into v_cod_persona
      from ge_cta_clientes
     where nro_cuenta = p_nro_cuenta
       and relacion = 'P';
    --Obtiene el Nombre del tipo de retencion
    select a.direccion, b.descripcion
      into v_direccion, v_localidad
      from ba_ciudades b, ba_direcciones a
     where a.cod_persona = v_cod_persona
       and a.principal = 'S'
       and a.cod_pais = b.cod_pais
       and a.cod_ciudad = b.cod_ciudad;
  exception
    when others then
      v_direccion := null;
      v_localidad := null;
  end;

  procedure lp_titulo(p_titulo varchar2) is
  begin
    pag_htm.PR_TABLA('S', 630, 20, 0); -- DEFINO LA TABLA
    pag_htm.PR_FILA('S', 'bgcolor="#003366"');
    pag_htm.PR_COLUMNA('&nbsp;&nbsp;' || p_titulo,
                       NULL,
                       'left',
                       'S',
                       'class="temas"'); -- agrego la columna etiqueta
    pag_htm.PR_FILA('N');
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
  end;

  function lf_for_tarjeta(p_nro_tarjeta in varchar2) return varchar2 is

  begin
    if length(p_nro_tarjeta) = 16 then
      return substr(p_nro_Tarjeta, 1, 4) || ' ' || substr(p_nro_Tarjeta,
                                                          5,
                                                          4) || ' ' || substr(p_nro_Tarjeta,
                                                                              9,
                                                                              4) || ' ' || substr(p_nro_Tarjeta,
                                                                                                  13,
                                                                                                  4);
    else
      return p_nro_Tarjeta;
    end if;
  end;

begin
  --identifica si el parámetro es una cuenta o una tarjeta
  if length(p_nro_tarjeta) = 16 then
    -- es un tarjeta de crédito
    begin
      select nro_cuenta, nom_embozar, nro_tarjeta
        into v_nro_cuenta, v_nombre, v_nro_tarjeta
        from ta_tarjetas b
       where b.nro_tarjeta = p_nro_tarjeta;
    exception
      when no_data_found then
        v_error := 'No existe Tarjeta de Crédito. Avise al Oficial.';
      when others then
        v_error := 'No se puede imprimir el Comprobante. Recup.Tarj.Crédito ' ||
                   sqlerrm;
    end;
  else
    v_nro_cuenta := p_nro_tarjeta;
    -- es un tarjeta de crédito
    begin
      select nro_cuenta, nom_embozar, nro_tarjeta
        into v_nro_cuenta, v_nombre, v_nro_tarjeta
        from ta_tarjetas b
       where b.nro_cuenta = p_nro_tarjeta
         and b.vigente = 'S'
         and rownum = 1
         and b.cod_persona = (select cod_persona
                                from ge_Cta_clientes
                               where nro_cuenta = p_nro_tarjeta
                                 and relacion = 'P');
    exception
      when no_data_found then
        v_error := 'No existe Tarjeta de Crédito. Avise al Oficial.';
      when others then
        v_error := 'No se puede imprimir el Comprobante. Recup.Tarj.Crédito ' ||
                   sqlerrm;
    end;
  end if;
  if v_error is null then
    --recupera los datos de la cuentas
    pag_cta.PR_OBT_CUENTA(v_nro_cuenta);
    IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
      v_error := 'Recup.Cta ' || pag_cta.fu_obt_msj_error();
    ELSE
      if (to_char(v_fecha, 'mmyyyy') = '012000') then
        pag_ban.pr_ext_actual(p_nro_tarjeta);
      else
        pag_ban.pr_ext_anterior(p_nro_tarjeta, v_fecha);
      end if;
      if pag_ban.fu_obt_cod_error() != '00' then
        -- tiene error
        v_error := pag_ban.fu_obt_cod_error() || ' - ' ||
                   pag_ban.fu_obt_msj_error();
      end if;
    END IF;
  end if;
  --arma html
  pag_htm.v_texto := null; -- inicializo el texto
  pag_htm.PR_ENCABEZADO;
  pag_htm.PR_CUERPO('S'); -- ABRE EL CUERPO

  --
  --si hubo error devolver el msj de error, sino imprimir comprobante
  if v_error is not null then
    pag_htm.PR_TABLA('S', 630, 50, 0); -- DEFINO LA TABLA
    pag_htm.PR_COLUMNA(v_error, NULL, 'center', 'S'); -- agrego la columna etiqueta
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
  else
    lp_obt_direccion(v_nro_cuenta);
    -- cabecera
    pag_htm.pr_texto('<br>');
    pag_htm.PR_TABLA('S', 630, 20, 0); -- DEFINO LA TABLA
    pag_htm.PR_FILA('S', 'bgcolor="#003366"');
    pag_htm.PR_COLUMNA('&nbsp;TARJETA', 130, NULL, 'S', 'class="temas"'); -- agrego la columna 
    pag_htm.PR_COLUMNA(lf_for_tarjeta(v_nro_tarjeta) || ' - ' || v_nombre,
                       500,
                       NULL,
                       'N',
                       'class="temas"'); -- agrego la columna
    pag_htm.PR_FILA('N');
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    pag_htm.PR_TABLA('S', 630, null, 0); -- DEFINO LA TABLA
    pag_htm.PR_FILA('S');
    pag_htm.PR_COLUMNA('&nbsp;Tipo', 130, NULL, 'S', 'bgcolor="#eeeeee"'); -- agrego la columna 
    pag_htm.PR_COLUMNA(fug_obt_des_modal(pag_cta.g_CTAS.COD_MODULO,
                                         pag_cta.g_CTAS.COD_modalidad),
                       500,
                       NULL,
                       'N',
                       'bgcolor="#eeeeee"'); -- agrego la columna
    pag_htm.PR_FILA('N');
    pag_htm.PR_FILA('S');
    pag_htm.PR_COLUMNA('&nbsp;Moneda', 130, NULL, 'S', 'bgcolor="#eeeeee"'); -- agrego la columna 
    pag_htm.PR_COLUMNA(fue_obt_titulo(fue_obt_des_moneda(pag_cta.g_CTAS.cod_moneda)),
                       500,
                       NULL,
                       'N',
                       'bgcolor="#eeeeee"'); -- agrego la columna
    pag_htm.PR_FILA('N');
    pag_htm.PR_FILA('S');
    pag_htm.PR_COLUMNA('&nbsp;Correspondiente a',
                       130,
                       NULL,
                       'S',
                       'bgcolor="#eeeeee"'); -- agrego la columna
    if (to_char(v_fecha, 'mmyyyy') = '012000') then
      pag_htm.PR_COLUMNA(substr(fug_des_fecha(v_fec_actual), 5),
                         500,
                         NULL,
                         'N',
                         'bgcolor="#eeeeee"'); -- agrego la columna
    else
      pag_htm.PR_COLUMNA(substr(fug_des_fecha(v_fecha), 5),
                         500,
                         NULL,
                         'N',
                         'bgcolor="#eeeeee"'); -- agrego la columna
    end if;
    pag_htm.PR_FILA('N');
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    pag_htm.pr_texto('<br/><b/r>');
    --  DATOS DEL TITULAR
    lp_titulo('DATOS DEL TITULAR');
    pag_htm.PR_TABLA('S', 630, 20, 1); -- DEFINO LA TABLA
    pag_htm.PR_FILA('S');
    pag_htm.PR_COLUMNA('&nbsp;Cuenta de Pago',
                       100,
                       NULL,
                       NULL,
                       'bgcolor="#F0F0F0"'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;' || v_nro_cuenta, 215); -- agrego la columna 
    pag_htm.PR_COLUMNA('&nbsp;Localidad',
                       100,
                       NULL,
                       NULL,
                       'bgcolor="#F0F0F0"'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;' || v_localidad, 215); -- agrego la columna             
    pag_htm.PR_FILA('N');
    pag_htm.PR_FILA('S');
    pag_htm.PR_COLUMNA('&nbsp;Nombre',
                       NULL,
                       NULL,
                       NULL,
                       'bgcolor="#F0F0F0"'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;' || pag_ban.fu_nom_cliente()); -- agrego la columna 
    pag_htm.PR_COLUMNA('&nbsp;Direcci&oacute;n',
                       NULL,
                       NULL,
                       NULL,
                       'bgcolor="#F0F0F0"'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;' || v_direccion); -- agrego la columna             
    pag_htm.PR_FILA('N');
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    ---- DATOS DE LA TARJETA
    pag_htm.PR_TEXTO('<br><br>');
    lp_titulo('DATOS DE LA TARJETA');
    pag_htm.PR_TABLA('S', 630, 20, 1); -- DEFINO LA TABLA
    pag_htm.PR_FILA('S');
    pag_htm.PR_COLUMNA('&nbsp;Pago M&iacute;nimo Gs.',
                       100,
                       NULL,
                       NULL,
                       'bgcolor="#F0F0F0"'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;' ||
                       lf_for_monto(pag_ban.fu_Pago_min_pendiente()),
                       215,
                       'right'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;Venc. Actual',
                       100,
                       NULL,
                       NULL,
                       'bgcolor="#F0F0F0"'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;' ||
                       lf_for_fecha(pag_ban.fu_Fec_ven_pag_minimo()),
                       215); -- agrego la columna
    pag_htm.PR_FILA('N');
    pag_htm.PR_FILA('S');
    pag_htm.PR_COLUMNA('&nbsp;L&iacute;mite de Cr&eacute;dito',
                       NULL,
                       NULL,
                       NULL,
                       'bgcolor="#F0F0F0"'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;' || lf_for_monto(pag_ban.fu_Lin_credito()),
                       null,
                       'right'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;Disponible',
                       NULL,
                       NULL,
                       NULL,
                       'bgcolor="#F0F0F0"'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;' ||
                       lf_for_monto(pag_ban.fu_Dis_com_normal() /*+pag_ban.fu_Dis_com_cuotas()*/),
                       null,
                       'right'); -- agrego la columna
    --pag_htm.PR_COLUMNA('&nbsp;'); -- agrego la columna
    pag_htm.PR_FILA('N');
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA

    ---- DATOS DE LOS MOVIMIENTOS
    pag_htm.PR_TEXTO('<br><br>');
    lp_titulo('MOVIMIENTOS');
    pag_htm.PR_TABLA('S', 630, 44, 1); -- DEFINO LA TABLA
    pag_htm.PR_FILA('S', 'bgcolor="#F0F0F0"');
    pag_htm.PR_COLUMNA('&nbsp;<b>Nro.Tarjeta</b>',
                       95,
                       null,
                       'N',
                       'rowspan=2'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;<b>Detalle</b>', 255, null, 'N', 'rowspan=2'); -- agrego la columna 
    pag_htm.PR_COLUMNA('&nbsp;<b>Fecha Operacion</b>',
                       70,
                       null,
                       'N',
                       'rowspan=2'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;<b>Guaranies</b>',
                       210,
                       'center',
                       'N',
                       'colspan=2'); -- agrego la columna
    pag_htm.PR_FILA('N');
    pag_htm.PR_FILA('S', 'bgcolor="#F0F0F0"');
    pag_htm.PR_COLUMNA('<b>Nro. Cupon&nbsp;</b>', 105, 'right'); -- agrego la columna                         
    pag_htm.PR_COLUMNA('<b>Importe&nbsp;</b>', 105, 'right'); -- agrego la columna 
    pag_htm.PR_FILA('N');
    -- ciclo de movimientos
    for i in 1 .. pag_ban.g_can_movimientos loop
      if (p_ver_todos = 'T' or (p_ver_todos = 'S' and pag_ban.t_movimientos(i)
         .nroTarjeta = v_nro_tarjeta)) then          
        if pag_ban.t_movimientos(i).nroTarjeta <> v_nro_tarjeta then
          v_tar_adicional := 0;
        else
          v_tar_adicional := 1;
        end if;
        if v_tar_adicional = 0 and (pag_ban.t_movimientos(i).nroTarjeta <> v_nro_tarjeta_ant 
          or v_nro_tarjeta_ant is null) then
          v_nro_tarjeta_ant := pag_ban.t_movimientos(i).nroTarjeta;         
          pag_htm.PR_FILA('S', 'bgcolor="#F0F0F0"');
          pag_htm.PR_COLUMNA('&nbsp;', 70);
          pag_htm.PR_COLUMNA('&nbsp; <b>Tarjetas Adicionales</b>', 95);
          for t in 1 .. pag_ban.g_can_tarjetas loop
             if pag_ban.t_tarjetas(t).nroTarjeta = pag_ban.t_movimientos(i).nroTarjeta then
                 pag_htm.PR_COLUMNA('&nbsp;'|| pag_ban.t_tarjetas(t).nombreCliente, 70);
             end if ;
          end loop ;
          pag_htm.PR_COLUMNA('&nbsp;', 70);
          pag_htm.PR_COLUMNA('&nbsp;', 70);
          pag_htm.PR_FILA('N');
        end if;      
        
        -- OMM 13/10/2011 Para identificar cuando es Movimiento de Tarjeta Principal
        if v_tar_principal = 0 and pag_ban.t_movimientos(i)
          .nroTarjeta = v_nro_tarjeta then
          pag_htm.PR_FILA('S', 'bgcolor="#F0F0F0"');
          pag_htm.PR_COLUMNA('&nbsp;', 70);
          pag_htm.PR_COLUMNA('&nbsp; <b>Tarjeta Principal</b>', 95);
          for p in 1 .. pag_ban.g_can_tarjetas loop
             if pag_ban.t_tarjetas(p).nroTarjeta = pag_ban.t_movimientos(i).nroTarjeta then
                 pag_htm.PR_COLUMNA('&nbsp;'|| pag_ban.t_tarjetas(p).nombreCliente, 70);
             end if ;
          end loop ;
          pag_htm.PR_COLUMNA('&nbsp;', 70);
          pag_htm.PR_COLUMNA('&nbsp;', 70);
          pag_htm.PR_FILA('N');
          v_tar_principal := 1;
        end if;
        
        pag_htm.PR_FILA('S');
        if instr(pag_ban.t_movimientos(i).descripcion, 'PAGO') > 0 and
           instr(pag_ban.t_movimientos(i).descripcion, 'PROMO') > 0 then
          v_transaccionEspecial := 1;
        end if;

        if pag_ban.t_movimientos(i)
         .NroCupon = 0 or v_cupon <> pag_ban.t_movimientos(i).NroCupon then
          pag_htm.PR_COLUMNA('&nbsp;' || pag_ban.t_movimientos(i)
                             .nroTarjeta,
                             95); -- agrego la columna
        else
          pag_htm.PR_COLUMNA('&nbsp;', 95); -- agrego la columna
        end if;

        if pag_ban.t_movimientos(i).tipoTransaccion = 'C' then
          pag_htm.PR_COLUMNA('&nbsp;' || pag_ban.t_movimientos(i)
                             .descripcion,
                             255); -- agrego la columna 
        else
          pag_htm.PR_COLUMNA('&nbsp;' || pag_ban.t_movimientos(i)
                             .descripcion || '&nbsp;(A confirmar)',
                             255); -- agrego la columna
        end if;
        if pag_ban.t_movimientos(i)
         .NroCupon = 0 or v_cupon <> pag_ban.t_movimientos(i).NroCupon then
          pag_htm.PR_COLUMNA('&nbsp;' ||
                             lf_for_fecha(pag_ban.t_movimientos(i)
                                          .FechaOperacion),
                             70); -- agrego la columna
        else
          pag_htm.PR_COLUMNA('&nbsp;', 70); -- agrego la columna
        end if;
        pag_htm.PR_COLUMNA(pag_ban.t_movimientos(i).NroCupon || '&nbsp;',
                           NULL,
                           'right',
                           105); -- agrego la columna
        pag_htm.PR_COLUMNA(lf_for_monto(pag_ban.t_movimientos(i).importe) ||
                           '&nbsp;',
                           NULL,
                           'right',
                           105); -- agrego la columna
        pag_htm.PR_FILA('N');
        v_cupon := pag_ban.t_movimientos(i).NroCupon;
      end if;
      -- dbms_output.put_line ('Nro ' || pag_ban.t_movimientos(i).nroTarjeta||' '||pag_ban.t_movimientos(i).importe);
    end loop;

    -- END LOOP
    pag_htm.PR_FILA('S', 'bgcolor="#F0F0F0"');
    pag_htm.PR_COLUMNA('<b>Deuda Cierre Anterior</b>&nbsp;',
                       420,
                       'right',
                       'N',
                       'colspan=3'); -- agrego la columna
    pag_htm.PR_COLUMNA(lf_for_monto(pag_ban.fu_deu_cie_anterior()) ||
                       '&nbsp;',
                       105,
                       'right'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp; ', 105); -- agrego la columna   
    pag_htm.PR_FILA('N');
    pag_htm.PR_FILA('S');
    pag_htm.PR_COLUMNA('<b>Total de D&eacute;bitos del Mes</b>&nbsp;',
                       420,
                       'right',
                       'N',
                       'colspan=3'); -- agrego la columna
    pag_htm.PR_COLUMNA(lf_for_monto(pag_ban.fu_tot_deb_mes()) || '&nbsp;',
                       105,
                       'right'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp; ', 105); -- agrego la columna     
    pag_htm.PR_FILA('N');
    pag_htm.PR_FILA('S', 'bgcolor="#F0F0F0"');
    pag_htm.PR_COLUMNA('<b>Total de Cr&eacute;ditos del Mes</b>&nbsp;',
                       420,
                       'right',
                       'N',
                       'colspan=3'); -- agrego la columna
    pag_htm.PR_COLUMNA(lf_for_monto(pag_ban.fu_tot_cre_mes()) || '&nbsp;',
                       105,
                       'right'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp;', 105); -- agrego la columna  
    pag_htm.PR_FILA('N');
    pag_htm.PR_FILA('S');
    pag_htm.PR_COLUMNA('<b>Saldo Deuda Cuota</b>&nbsp;',
                       420,
                       'right',
                       'N',
                       'colspan=3'); -- agrego la columna
    pag_htm.PR_COLUMNA(lf_for_monto(pag_ban.fu_Deu_com_cuotas()) ||
                       '&nbsp;',
                       105,
                       'right'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp; ', 105); -- agrego la columna    
    pag_htm.PR_FILA('N');
    pag_htm.PR_FILA('S', 'bgcolor="#F0F0F0"');
    pag_htm.PR_COLUMNA('<b>Deuda Total</b>&nbsp;',
                       420,
                       'right',
                       'N',
                       'colspan=3'); -- agrego la columna
    pag_htm.PR_COLUMNA(lf_for_monto(pag_ban.fu_Deu_total()) || '&nbsp;',
                       105,
                       'right'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp; ', 105); -- agrego la columna    
    pag_htm.PR_FILA('N');
    pag_htm.PR_FILA('S');
    pag_htm.PR_COLUMNA('<b>Deuda Actual</b>&nbsp;',
                       420,
                       'right',
                       'N',
                       'colspan=3'); -- agrego la columna
    pag_htm.PR_COLUMNA(lf_for_monto(pag_ban.fu_Deu_total()) || '&nbsp;',
                       105,
                       'right'); -- agrego la columna
    pag_htm.PR_COLUMNA('&nbsp; ', 105); -- agrego la columna   
    pag_htm.PR_FILA('N');

    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA

  end if;
  ---
  pag_htm.PR_CUERPO('N'); -- cierro el body
  pag_htm.PR_PIE; -- pie del html

  ---
  v_retorno := v_retorno || pag_htm.v_texto;
  return v_retorno;
end FUW_IMP_EXT_TARJETA;
/

