create or replace function it.FUJ_IMP_TRANSACCION_250
  (p_cod_oficina   IN NUMBER,
   p_nro_operacion in number,
   p_nro_caja      in number,
   p_cod_moneda    IN VARCHAR2,
   p_nro_cuenta    IN VARCHAR2,
   p_fecha         IN DATE,
   p_hora          IN VARCHAR2)
 return varchar2 is
  v_ancho     number(3) := 40; -- ancho del reporte
  v_vez       number(01) := 0;
  v_resultado varchar2(4000) := null;
  v_linea     varchar2(200);
  v_cod_persona ba_personas.cod_persona%type;
  v_nom_completo ba_personas.nom_completo%type;
  v_nro_documento ba_personas.nro_documento%type;
  v_fec_vencimiento pr_cuotas.fec_vencimiento%type;
  v_mto_cuota number(18,2);
  v_int_mor_cap number(18,2);
  v_int_mor_int number(18,2);
  v_int_mor_ade number(18,2);
  v_int_punitorio number(18,2);
  v_imp_mor_cap number(18,2);
  v_imp_mor_int number(18,2);
  v_imp_mor_ade number(18,2);
  v_imp_punitorio number(18,2);
  v_impuesto number(18,2);
  v_cargo number(18,2);
  v_iva number(18,2);
  v_total number(18,2);
  v_monto number(18,2);
  v_total_cargos number(18,2);
  v_cuo_pag varchar2(30);
  v_nro_impresion number(10);
  v_can_cuotas pr_cta_prestamos.can_cuotas%type;
  v_pri_cuota pr_cta_prestamos.can_cuotas%type;
  v_ult_cuota pr_cta_prestamos.can_cuotas%type;
  v_nro_cuenta pr_cta_prestamos.nro_cuenta%type;
  v_cod_usuario ba_usuarios.cod_usuario%type;
  v_hasta number;
  v_denominacion varchar2(4000);
  v_moneda ba_monedas.descripcion%type;
  v_redondeo number(2) := 0;
  v_nro_factura ge_movimientos.nro_documento%type := 0;
  v_cod_oficina ba_oficinas.cod_oficina%type;
  v_mon_utilizado number(18,2);
  v_mon_cubierto  number(18,2);
  v_tot_cobrado   number(18,2);
  v_mostar_che    varchar2(1) := 'N';
  v_des_modal     ge_modalidades.descripcion%type;
  v_nro_tarjeta   ta_tarjetas.nro_tarjeta%type;
  --- Cursor de cuotas cobradas
  cursor c_cuotas_cob is
  select c.cod_persona , c.nom_completo, c.nro_documento,
         a.fec_proceso fec_vencimiento,
         a.monto cuota,
         1 nro_cuota, 1 can_cuotas,
         d.descripcion des_modal,
         a.nro_tarjeta
   from ba_personas c, ge_cta_clientes b, ta_cobros a, ge_modalidades d
   where a.nro_cuenta = b.nro_cuenta
     and b.relacion = 'P' -- cliente principal
     and c.cod_persona = b.cod_persona
     and a.nro_cuenta = p_nro_cuenta
     and a.fec_proceso = p_fecha
     and a.hora = p_hora
     and d.cod_modulo = b.cod_modulo
     and d.cod_modalidad = b.cod_modalidad;
  --order by a.nro_cuota;
  --- Cursor de formas de cobro
  cursor c_forma_cob is
  select DECODE(m.cod_transaccion, 503, 'DEB.AV: '||m.nro_cuenta,
                                   607, 'CHEQUE',
                                   690, 'EFECTIVO',
                                        t.descripcion) descripcion,
         m.monto, m.cod_moneda, m.cod_transaccion
    from ge_movimientos m, ge_transacciones t
   where m.cod_modulo = t.cod_modulo
     and m.cod_modalidad = t.cod_modalidad
     and m.cod_transaccion = t.cod_transaccion
     and m.fecha = p_fecha
     and m.hora = p_hora
     and m.cod_usuario = v_cod_usuario
     and m.cod_transaccion in (690,607,503)
     and (m.monto <= v_monto or v_monto is null)
  order by monto desc;
  --- Cursor de detalle de cheques
  cursor c_cheques is
  select c.cod_banco, b.sigla abreviatura,
         c.nro_cheque, nvl(c.monto,0) monto
    from ge_cheques_det c, ge_bancos b
   where c.nro_cuenta = p_nro_cuenta
     and c.fec_ingreso = p_fecha
     and c.nro_documento = p_nro_operacion
     and c.cod_banco = b.cod_banco
   order by 2,3;
  function fu_obt_des_mon(p_cod_moneda in varchar2) return varchar2 is
    v_des_moneda ba_monedas.descripcion%type;
  Begin
    Select InitCap(descripcion)
      into v_des_moneda
      from ba_monedas
     where cod_moneda = p_cod_moneda;
    Return v_des_moneda;
  Exception
    When NO_DATA_FOUND then
         return null;
  end;
begin
  --Obtener la oficina matriz de la entidad
  select cod_ofi_matriz into v_cod_oficina from ge_par_generales;
  -- seteo la oficina
  pag_imp.pr_set_oficina(v_cod_oficina);
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
  -- imprimo la cabecera
  If p_cod_moneda != pag_gen.fu_obt_mon_local then
     v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6);
  End if;
  v_moneda := fu_obt_des_mon(p_cod_moneda);
  --- Faltan datos de la Financiera
  v_nro_impresion := 0;
  dbms_output.put_line('Trae cj_movimientos:'||to_char(p_nro_operacion));
  Begin
    Select nvl(count(*),0) + 1
      into v_nro_impresion
      from cj_movimientos
     where cod_tra_padre = 110
       and cod_mod_padre = 9
       and cod_mad_padre = 91
       and nro_documento = p_nro_operacion;
  End;
  IF p_nro_caja is not null then
    dbms_output.put_line('Pasa por ##-004:'||to_char(p_nro_operacion));
    begin
       select distinct cod_usuario
         into v_cod_usuario
         from cj_movimientos
        where nro_documento = p_nro_operacion
          and cod_tra_padre in (250);
    Exception
       When NO_DATA_FOUND then
            raise_application_error(-20000, 'Operacion inexistente '||p_nro_operacion);
       When TOO_MANY_ROWS then
            raise_application_error(-20000, 'Operacion duplicada '||p_nro_operacion);
    end;
  else
    v_cod_usuario := user;
  end if;

  --- IMPRESION DEL RECIBO ---
  dbms_output.put_line('Pasa por ##-005:'||to_char(p_nro_operacion));
  if p_nro_operacion is not null then
    -- leo los datos del pago de prestamos
    v_mto_cuota     := 0;
    v_int_mor_cap   := 0;
    v_int_mor_int   := 0;
    v_int_mor_ade   := 0;
    v_int_punitorio := 0;
    v_impuesto      := 0;
    v_cargo         := 0;
    v_iva           := 0;
    v_cuo_pag       := null;
    dbms_output.put_line('Trae datos de cobro:'||to_char(p_nro_operacion));
    for cuo in c_cuotas_cob loop
       v_cod_persona     := cuo.cod_persona;
       v_nom_completo    := cuo.nom_completo;
       v_nro_documento   := cuo.nro_documento;
       v_nro_tarjeta     := cuo.nro_tarjeta;
       v_fec_vencimiento := cuo.fec_vencimiento;
       v_can_cuotas      := cuo.can_cuotas;
       v_mto_cuota       := nvl(v_mto_cuota,0) + nvl(cuo.cuota,0);
       v_des_modal       := cuo.des_modal;
       if v_cuo_pag is null then
          v_cuo_pag   := cuo.nro_cuota;
          v_pri_cuota := cuo.nro_cuota;
       else
          v_ult_cuota := cuo.nro_cuota;
       end if;
    end loop;
    if v_pri_cuota <> v_ult_cuota then
       v_cuo_pag := v_cuo_pag||' al '||v_ult_cuota;
    end if;
  If v_mto_cuota != 0 then
    pag_imp.pr_imp_cab_centrada(v_resultado,  -- texto
                             'RECIBO DE DINERO: '||to_char(p_nro_operacion), -- titulo
                             '*** COBRO DE TARJETAS DE CREDITO ***',  -- SUB titulo
                             1, -- lineas antes
                             0); -- lineas despues

    v_linea := 'IMPRESION: '||v_nro_impresion;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 0, 0, 'S');
    -- imprimo la fecha y hora
    v_linea := 'Fecha: '||to_char(p_fecha,'dd/mm/yyyy')||'               '||p_hora;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 2, /*lin.antes*/ 0 /*col.antes*/ );
    -- Imprimo datos del cajero
    v_linea := 'Caja Nro.: '||lpad(p_nro_caja,3,' ');--||lpad('Cajero: '||user,26,' ');
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1, 0);
    --Hallar el nro de factura del desembolso
    --begin
    --  select nro_documento2
    --    into v_nro_factura
    --    from gv_movimientos
    --    where nro_cuenta = p_nro_cuenta
    --      and cod_tra_padre = 358
    --      and cod_transaccion = 711
    --      and fecha >= to_date('01/01/2006','DD/MM/YYYY');
    --exception
    -- when no_data_found then
    --   v_nro_factura :=  0;
    --end;
    -- Imprimo el Nro. de Factura
    v_linea := 'Factura Nro.: '||rpad(nvl(v_nro_factura,0),15,' ')||'Sucursal:'||lpad(to_char(v_cod_oficina),2,' ');
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1, 0);
    --v_linea := 'Referencia Nro.: '||rpad(to_char(p_nro_factura),15,' ');
    --pag_imp.pr_imp_linea(v_resultado, v_linea, 1, 0);
    -- total cobrado
    v_total := v_mto_cuota +
               v_int_mor_cap + v_int_mor_int + v_int_mor_ade +
               v_int_punitorio +
               v_impuesto +
               v_cargo +
               v_iva ;
    -- datos del cliente y el prestamo
    if to_number(p_nro_cuenta) > 1000000 then
       v_nro_cuenta := to_number(substr(p_nro_cuenta,4,6));
    else
       v_nro_cuenta := p_nro_cuenta;
    end if;
    pag_imp.pr_imp_linea(v_resultado, 'Doc.: '||rpad(v_nro_documento,20,' ')||lpad('Cliente: '||v_cod_persona,14,' '), 2, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Sr/a: '||substr(v_nom_completo,1,34), 1, 0);
    --if to_number(p_nro_cuenta) > 1000000 then
    --   pag_imp.pr_imp_linea(v_resultado, 'Tarjeta: '||v_nro_cuenta||' ('||p_nro_cuenta||')', 1, 0);
    --else
    pag_imp.pr_imp_linea(v_resultado, 'Tarjeta: '||v_nro_tarjeta, 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Tipo   : '||substr(v_des_modal,1,31), 1, 0);

    --end if;
    --pag_imp.pr_imp_linea(v_resultado, 'Cuota/s : '||v_cuo_pag||' de '||v_can_cuotas, 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Recibimos  el  Cobro  en  concepto de su', 2, 0,'S');
    pag_imp.pr_imp_linea(v_resultado, 'Tarjeta de Credito arriba indicado.', 1, 0,'S');
    -- detalle de los cobros
    --pag_imp.pr_imp_linea(v_resultado, 'Fecha de Vencimiento: '||to_char(v_fec_vencimiento,'dd/mm/yyyy'), 2, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Importe Cobrado     : '||to_char(v_mto_cuota,'99,999,999,999.99'), 1, 0);

    --- Letras del monto pagado
    pag_imp.pr_imp_linea(v_resultado, 'Son: '||v_moneda||' '||fue_obt_denominacion(v_mto_cuota)||'.-',2,0);
--    v_denominacion := fue_obt_denominacion(v_mto_cuota);
--    pag_imp.pr_imp_linea(v_resultado, 'Son: '||v_denominacion,1,0);

--    v_denominacion := fue_obt_denominacion(v_mto_cuota);
--    v_hasta :=instr(substr(v_denominacion,1,35),' ',-1);
--    pag_imp.pr_imp_linea(v_resultado, 'Son: '||substr(v_denominacion,1,v_hasta),2,0);
--    pag_imp.pr_imp_linea(v_resultado, substr(v_denominacion,v_hasta+1,40),1,0);

    --- Formas de Cobro
    pag_imp.pr_imp_linea(v_resultado, 'FORMA DE COBRO', 2, 0);
    v_monto         := null;
    v_mon_utilizado := 0;
    v_mon_cubierto  := 0;
    v_tot_cobrado   := 0;
    for pag in c_forma_cob loop
       If pag.monto >= (v_mto_cuota - v_mon_cubierto) then
         v_mon_utilizado := (v_mto_cuota - v_mon_cubierto);
         v_mon_cubierto := v_mon_cubierto + (v_mto_cuota - v_mon_cubierto);
       else
         v_mon_utilizado := pag.monto;
         v_mon_cubierto := v_mon_cubierto + pag.monto;
       End if;
       v_tot_cobrado := v_tot_cobrado + v_mon_utilizado;
       --pag_imp.pr_imp_linea(v_resultado, rpad(pag.descripcion,20,' ')||': '||to_char(pag.monto,'99,999,999,999.99'), 1, 0);
       pag_imp.pr_imp_linea(v_resultado, rpad(pag.descripcion,20,' ')||': '||to_char(v_mon_utilizado,'99,999,999,999.99'), 1, 0);
       v_monto := pag.monto;
       If pag.cod_transaccion = 607 then
         v_mostar_che := 'S';
       End if;
       exit when v_mon_cubierto = v_mto_cuota;
    end loop;

    -- total
    pag_imp.pr_imp_linea(v_resultado, '                      ------------------', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'TOTAL COBRADO '||rpad(p_cod_moneda,3,' ')||'   : '||to_char(v_tot_cobrado,'99,999,999,999.99'), 1, 0);
    --- Detalle de Cheques
    v_vez := 0;
    If v_mostar_che = 'S' then
      for che in c_cheques loop
         if v_vez = 0 then
            --- Solo imprimir si hay cheques y la primera vez
            pag_imp.pr_imp_linea(v_resultado, 'DETALLE DE CHEQUES', 2, 0);
            v_vez := 1;
         end if;
         pag_imp.pr_imp_linea(v_resultado, rpad(che.abreviatura||' '||che.nro_cheque,20,' ')||': '||to_char(che.monto,'99,999,999,999.99'), 1, 0);
      end loop;
    End if;
    -- imprimo el pie
    pag_imp.pr_imp_linea(v_resultado, '----------------------------------------', 1, 0);
    --leyenda
    pag_imp.pr_imp_linea(v_resultado, '----------------------------------------', 11, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Este    formato   esta    aprobado   por', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Constancia de Comunicacion N.05484/05F, ', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'de la Subsecretaria de Estado de Tribu- ', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'tacion de fecha 29/12/2005              ', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, '*Original: Adquirente', 2, 0);
    pag_imp.pr_imp_linea(v_resultado, '                  *Copia1: Contribuyente', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, '                   *Copia2: Arch.Tribut.', 1, 0);

    pag_imp.pr_imp_pie(v_resultado, 2);   -- linea antes
    v_linea := null;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 10, 0);
  end if;
  --- FIN IMPRESION DEL RECIBO ---
 End If;
  return(v_resultado);
end FUJ_IMP_TRANSACCION_250;
/

