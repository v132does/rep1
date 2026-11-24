create or replace function it.FUJ_IMP_TRANSACCION_360
  (p_cod_oficina   IN NUMBER,
   p_nro_operacion in number,
   p_nro_factura   in varchar2,
   p_nro_caja      in number,
   p_cod_moneda    IN VARCHAR2,
   p_nro_cuenta    IN VARCHAR2,
   p_fecha         IN DATE,
   p_hora          IN VARCHAR2)
 return long  is
  v_ancho     number(3) := 40; -- ancho del reporte
  v_vez       number(01) := 0;
  v_resultado long;
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
  v_total_cargos number(18,2);
  v_cuo_pag varchar2(30);
  v_nro_impresion number(10);
  v_can_cuotas pr_cta_prestamos.can_cuotas%type;
  v_pri_cuota pr_cta_prestamos.can_cuotas%type;
  v_ult_cuota pr_cta_prestamos.can_cuotas%type;
  v_nro_cuenta pr_cta_prestamos.nro_cuenta%type;
  v_cod_usuario ba_usuarios.cod_usuario%type;
  v_hasta number;
  v_hasta2 number;
  v_denominacion varchar2(4000);
  v_moneda ba_monedas.descripcion%type;
  v_redondeo number(2) := 0;
  v_imp_cuenta number(18,2);
  v_ind_cheque varchar2(1) := 'N';
  v_cod_tra_padre cj_movimientos.cod_tra_padre%type; --CRO-HO-CROCPCCB-13/08/15 se declara variable para capturar transaccion
  v_tip_monto     varchar2(01);
  --- Cursor de cuotas cobradas
  cursor c_cuotas_cob is
  select c.cod_persona , c.nom_completo, c.nro_documento,
         a.fec_vencimiento,
         nvl(a.mto_capital,0)+ nvl(a.mto_interes,0) +
         nvl(a.mto_int_documentado,0) cuota,
         nvl(a.mto_int_moratorio,0)  int_mor_cap,
         nvl(a.mto_int_mor_interes,0) int_mor_int,
         nvl(a.mto_int_mor_adelantado,0) int_mor_ade,
         nvl(a.mto_int_punitorio,0) int_punitorio,
         nvl(a.mto_impuesto,0) impuesto,
         nvl(a.mto_cargo,0)-nvl(a.mto_cargo_iva,0) cargo,
         nvl(a.mto_cargo_iva,0) iva, a.nro_cuota, nvl(p.can_cuotas,0) can_cuotas
   from ba_personas c, ge_cta_clientes b, pr_cobros a, pr_cta_prestamos p
   where a.nro_cuenta = b.nro_cuenta
     and p.nro_cuenta = a.nro_cuenta
     and b.relacion = 'P' -- cliente principal
     and c.cod_persona = b.cod_persona
     and a.nro_cuenta = p_nro_cuenta
     and a.fecha = p_fecha
     and a.hora = p_hora
  order by a.nro_cuota;
  --- Cursor de cuotas cobradas TMP --CRO-HO-CROCPCCB-13/08/15 se define cursor, segun AT: CROAPARS-40
  cursor c_che_obco is
  select c.cod_persona , c.nom_completo, c.nro_documento,
         a.fec_vencimiento,
         nvl(a.mto_capital,0)+ nvl(a.mto_interes,0) +
         nvl(a.mto_int_documentado,0) cuota,
         nvl(a.mto_int_moratorio,0)  int_mor_cap,
         nvl(a.mto_int_mor_interes,0) int_mor_int,
         nvl(a.mto_int_mor_adelantado,0) int_mor_ade,
         nvl(a.mto_int_punitorio,0) int_punitorio,
         nvl(a.mto_impuesto,0) impuesto,
         nvl(a.mto_cargo,0)-nvl(a.mto_cargo_iva,0) cargo,
         nvl(a.mto_cargo_iva,0) iva, a.nro_cuota, nvl(p.can_cuotas,0) can_cuotas
   from ba_personas c, ge_cta_clientes b, pr_cobros_tmp a, pr_cta_prestamos p
   where a.nro_cuenta = b.nro_cuenta
     and p.nro_cuenta = a.nro_cuenta
     and b.relacion = 'P' -- cliente principal
     and c.cod_persona = b.cod_persona
     and a.nro_cuenta = p_nro_cuenta
  order by a.nro_cuota;
  --- Cursor de formas de cobro
  cursor c_forma_cob is
  select DECODE(m.cod_transaccion, 503, DECODE(FUG_OBT_TIP_IMPLEMENTACION,1,'DEB.CTA: ','DEB.AV: ')||m.nro_cuenta, t.descripcion) descripcion,
         m.monto, m.cod_moneda, m.cod_transaccion
    from ge_movimientos m, ge_transacciones t
   where m.cod_modulo = t.cod_modulo
     and m.cod_modalidad = t.cod_modalidad
     and m.cod_transaccion = t.cod_transaccion
     and m.fecha = p_fecha
     and m.hora = p_hora
     and m.cod_usuario = v_cod_usuario
     and m.cod_transaccion in (740,607,503,842,610,632,606,572)--(572:impuesto)
     and m.cod_tra_padre <> 309
  order by m.cod_transaccion;
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
  -- seteo la oficina
  pag_imp.pr_set_oficina(p_cod_oficina);
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
  -- imprimo la cabecera
  v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, p_cod_moneda);
  v_moneda := fu_obt_des_mon(p_cod_moneda);
  --- Faltan datos de la Financiera
  v_nro_impresion := 0;
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
    begin
       select distinct cod_usuario, cod_tra_padre, tip_monto --CRO-HO-CROCPCCB-13/08/15 Se obtiene el campo cod_tra_padre en la variable v_cod_tra_padre
         into v_cod_usuario, v_cod_tra_padre, v_tip_monto
         from cj_movimientos
        where nro_documento = p_nro_operacion
          and cod_tra_padre in (360, 359, 361, 362);
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
  if p_nro_operacion is not null or fug_obt_tip_implementacion = 1 then
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
    -- DYDMR-3496 se agrega v_tip_monto 'T' 48hs y 'S' 72 hs
    if v_cod_tra_padre = 361 or (v_cod_tra_padre in (359, 362) and v_tip_monto in ('O','T','S')) then --CRO-HO-CROCPCCB-10/08/15 Si la transaccion es 361, carga los datos desde el nuevo cursor c_che_obco
        for cho in c_che_obco loop
             v_cod_persona     := cho.cod_persona;
             v_nom_completo    := cho.nom_completo;
             v_nro_documento   := cho.nro_documento;
             v_fec_vencimiento := cho.fec_vencimiento;
             v_can_cuotas      := cho.can_cuotas;
             v_mto_cuota       := nvl(v_mto_cuota,0) + nvl(cho.cuota,0);
             v_int_mor_cap     := nvl(v_int_mor_cap,0) + nvl(cho.int_mor_cap,0);
             v_int_mor_int     := nvl(v_int_mor_int,0) + nvl(cho.int_mor_int,0);
             v_int_mor_ade     := nvl(v_int_mor_ade,0) + nvl(cho.int_mor_ade,0);
             v_int_punitorio   := nvl(v_int_punitorio,0) + nvl(cho.int_punitorio,0);
             v_impuesto        := nvl(v_impuesto,0) + nvl(cho.impuesto,0);
             v_cargo           := nvl(v_cargo,0) + nvl(cho.cargo,0);
             v_iva             := nvl(v_iva,0) + nvl(cho.iva,0);
             if v_cuo_pag is null then
                v_cuo_pag   := cho.nro_cuota;
                v_pri_cuota := cho.nro_cuota;
             else
                v_ult_cuota := cho.nro_cuota;
             end if;
          end loop;
      else
        for cuo in c_cuotas_cob loop
             v_cod_persona     := cuo.cod_persona;
             v_nom_completo    := cuo.nom_completo;
             v_nro_documento   := cuo.nro_documento;
             v_fec_vencimiento := cuo.fec_vencimiento;
             v_can_cuotas      := cuo.can_cuotas;
             v_mto_cuota       := nvl(v_mto_cuota,0) + nvl(cuo.cuota,0);
             v_int_mor_cap     := nvl(v_int_mor_cap,0) + nvl(cuo.int_mor_cap,0);
             v_int_mor_int     := nvl(v_int_mor_int,0) + nvl(cuo.int_mor_int,0);
             v_int_mor_ade     := nvl(v_int_mor_ade,0) + nvl(cuo.int_mor_ade,0);
             v_int_punitorio   := nvl(v_int_punitorio,0) + nvl(cuo.int_punitorio,0);

             v_impuesto        := nvl(v_impuesto,0) + nvl(cuo.impuesto,0);
             v_cargo           := nvl(v_cargo,0) + nvl(cuo.cargo,0);
             v_iva             := nvl(v_iva,0) + nvl(cuo.iva,0);
             if v_cuo_pag is null then
                v_cuo_pag   := cuo.nro_cuota;
                v_pri_cuota := cuo.nro_cuota;
             else
                v_ult_cuota := cuo.nro_cuota;
             end if;
         end loop;
    end if;
    if v_pri_cuota <> v_ult_cuota then
       v_cuo_pag := v_cuo_pag||' al '||v_ult_cuota;
    end if;
    -- total cobrado
    v_total := v_mto_cuota +
               v_int_mor_cap + v_int_mor_int + v_int_mor_ade +
               v_int_punitorio +
               v_impuesto +
               v_cargo +
               v_iva ;    
  If v_total != 0 then
    pag_imp.pr_imp_cab_centrada(v_resultado,  -- texto
                             '*** PAGO DE PRESTAMOS ***',  -- titulo
                             'RECIBO DE DINERO: '||to_char(p_nro_operacion), -- sub titulo
                             1, -- lineas antes
                             0); -- lineas despues

    v_linea := 'IMPRESION: '||v_nro_impresion;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 0, 0, 'S');
    -- imprimo la fecha y hora
    v_linea := 'Fecha: '||to_char(p_fecha,'dd/mm/yyyy')||'               '||p_hora;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 2, /*lin.antes*/ 0 /*col.antes*/ );
    -- Imprimo datos del cajero
    if fug_obt_tip_implementacion <> 1 then
      v_linea := 'Caja Nro.: '||lpad(p_nro_caja,3,' ')||lpad('Cajero: '||user,26,' ');
    else
      v_linea := 'Caja Nro.: '||lpad(p_nro_caja,3,' ');--||lpad('Usuario: '||user,25,' ');
    end if;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1, 0);
    -- Imprimo el Nro. de Factura
    ---v_linea := 'Factura Nro.: '||rpad(p_nro_factura,26,' ');
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
    if to_number(p_nro_cuenta) > 1000000 then
       pag_imp.pr_imp_linea(v_resultado, 'Prestamo: '||v_nro_cuenta||' ('||p_nro_cuenta||')', 1, 0);
    else
       pag_imp.pr_imp_linea(v_resultado, 'Prestamo: '||p_nro_cuenta, 1, 0);
    end if;
    pag_imp.pr_imp_linea(v_resultado, 'Cuota/s : '||v_cuo_pag||' de '||v_can_cuotas, 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Recibimos  el  Pago  en  concepto  de su', 2, 0,'S');
    pag_imp.pr_imp_linea(v_resultado, 'Prestamo arriba indicado,  segun detalle', 1, 0,'S');
    -- detalle de los cobros
    pag_imp.pr_imp_linea(v_resultado, 'Fecha de Vencimiento: '||to_char(v_fec_vencimiento,'dd/mm/yy'), 2, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Monto de la Cuota   : '||to_char(v_mto_cuota,'99,999,999,999.99'), 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Interes Moratorio   : '||to_char(v_int_mor_cap+v_int_mor_int+v_int_mor_ade,'99,999,999,999.99'), 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Interes Punitorio   : '||to_char(v_int_punitorio,'99,999,999,999.99'), 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Cargos IVA incluido : '||to_char(v_cargo+v_iva,  '99,999,999,999.99'), 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Impuesto            : '||to_char(v_impuesto,'99,999,999,999.99'), 1, 0);
    --- Letras del monto pagado
    --pag_imp.pr_imp_linea(v_resultado, 'Son: '||v_moneda||' '||fue_obt_denominacion(v_mto_cuota)||'.-',2,0);
    /*dyd-mr1554 fm 02/02/2015 */
    --v_denominacion := 'Son: '||v_moneda||' '||fue_obt_denominacion(v_mto_cuota);
    v_denominacion := 'Son: '||v_moneda||' '||fue_obt_denominacion(v_total);
    if length(v_denominacion) > 40 then
       v_hasta :=instr(substr(v_denominacion,1,40),' ',-1);
       /*if length(substr(v_denominacion,v_hasta+1,v_hasta+41)) > 40 then
          v_hasta2 :=instr(substr(v_denominacion,v_hasta+1,v_hasta+41),' ',-1);
       else
          v_hasta2 :=length(v_denominacion);
       end if;*/
    else
       v_hasta := length(v_denominacion);
    end if;   
    pag_imp.pr_imp_linea(v_resultado, substr(v_denominacion,1,v_hasta),2,0);
    pag_imp.pr_imp_linea(v_resultado, substr(v_denominacion,v_hasta+1),1,0);
--    pag_imp.pr_imp_linea(v_resultado, substr(v_denominacion,v_hasta+1,v_hasta2),1,0);
--    pag_imp.pr_imp_linea(v_resultado, substr(v_denominacion,v_hasta2+1),1,0);

    --- Formas de Cobro
    pag_imp.pr_imp_linea(v_resultado, 'FORMA DE COBRO', 2, 0);
    for pag in c_forma_cob loop
       if pag.cod_transaccion = 572 then --impuesto
           v_imp_cuenta := pag.monto;
       else
           if pag.cod_transaccion in (607,610,632) then
              v_ind_cheque := 'S';
           end if;
           pag_imp.pr_imp_linea(v_resultado, rpad(pag.descripcion,20,' ')||': '||to_char(pag.monto,'99,999,999,999.99'), 1, 0);
       end if;
    end loop;
    -- total
    pag_imp.pr_imp_linea(v_resultado, '                      ------------------', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'TOTAL COBRADO '||rpad(p_cod_moneda,3,' ')||'   : '||to_char(v_total,'99,999,999,999.99'), 1, 0);
    --impuesto, si corresponde
    if fug_obt_tip_implementacion = 1 and nvl(v_imp_cuenta,0) >0 then
       pag_imp.pr_imp_linea(v_resultado, 'Impuesto Ley 125    : '||to_char(v_imp_cuenta,'99,999,999,999.99'), 1, 0);
    end if;
    --- Detalle de Cheques
    v_vez := 0;
    for che in c_cheques loop
       if v_vez = 0 then
          --- Solo imprimir si hay cheques y la primera vez
          pag_imp.pr_imp_linea(v_resultado, 'DETALLE DE CHEQUES', 2, 0);
          v_vez := 1;
       end if;
       pag_imp.pr_imp_linea(v_resultado, rpad(che.abreviatura||' '||che.nro_cheque,20,' ')||': '||to_char(che.monto,'99,999,999,999.99'), 1, 0);
    end loop;

    pag_imp.pr_imp_linea(v_resultado, '----------------------------------------', 1, 0);
    
    -- Al comprobante de pago de prestamos realizados por caja, se agregue los datos de la persona que realiza el pago. 
    -- DYD-SDSL-3069 
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('_',30,'_'),2);
  pag_imp.PR_IMP_LINEA(v_resultado,('Firma de Per. que realiza la Op.'),1);
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('_',30,'_'),2);
  pag_imp.PR_IMP_LINEA(v_resultado,('Aclaracion de Firma'),1);
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('_',30,'_'),2);
  pag_imp.PR_IMP_LINEA(v_resultado,('Tipo y Nro. Documento'),1);
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('_',30,'_'),2);
  pag_imp.PR_IMP_LINEA(v_resultado,('Direccion'),1);
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1); 
---------------------------------------
 
    -- imprimo el pie
    pag_imp.pr_imp_linea(v_resultado, 'Este comprobante no  es  valido  sin  la', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'firma y sello del cajero.               ', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, '----------------------------------------', 1, 0);
    if v_ind_cheque = 'S' then
      pag_imp.pr_imp_linea(v_resultado, 'Cobro sujeto a confirmacion del cheque  ', 1, 0);
      pag_imp.pr_imp_linea(v_resultado, '----------------------------------------', 1, 0);
    end if;  
    /*
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
    */
    pag_imp.pr_imp_pie(v_resultado, 2);   -- linea antes
    v_linea := null;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 10, 0);
  end if;
  --- FIN IMPRESION DEL RECIBO ---
 End If;

  --- IMPRESION DE LA FACTURA ---BR. no imprime factura
  if p_nro_factura is not null and fug_obt_tip_implementacion <> 1 then
    pag_imp.pr_imp_cab_centrada(v_resultado,  -- texto
                             '*** PAGO DE PRESTAMOS ***',  -- titulo
                             'FACTURA CONTADO: '||to_char(p_nro_factura), -- sub titulo
                             1, -- lineas antes
                             0); -- lineas despues

    v_linea := 'IMPRESION: '||v_nro_impresion;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 0, 0, 'S');
    -- imprimo la fecha y hora
    v_linea := 'Fecha: '||to_char(p_fecha,'dd/mm/yyyy')||'               '||p_hora;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 2, /*lin.antes*/ 0 /*col.antes*/ );
    -- Imprimo datos del cajero
    if fug_obt_tip_implementacion <> 1 then
      v_linea := 'Caja Nro.: '||lpad(p_nro_caja,3,' ')||lpad('Cajero: '||user,26,' ');
    else
      v_linea := 'Caja Nro.: '||lpad(p_nro_caja,3,' ')||lpad('Usuario: '||user,25,' ');
    end if;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1, 0);

    -- Imprimo el Nro. de Recibo
    v_linea := 'Recibo Nro.: '||rpad(p_nro_operacion,15,' ')||' Sucursal:'||to_char(p_cod_oficina);
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1, 0);

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
    for cuo in c_cuotas_cob loop
       v_cod_persona     := cuo.cod_persona;
       v_nom_completo    := cuo.nom_completo;
       v_nro_documento   := cuo.nro_documento;
       v_fec_vencimiento := cuo.fec_vencimiento;
       v_can_cuotas      := cuo.can_cuotas;
       v_mto_cuota       := nvl(v_mto_cuota,0) + nvl(cuo.cuota,0);
       v_int_mor_cap     := nvl(v_int_mor_cap,0) + nvl(cuo.int_mor_cap,0);
       v_int_mor_int     := nvl(v_int_mor_int,0) + nvl(cuo.int_mor_int,0);
       v_int_mor_ade     := nvl(v_int_mor_ade,0) + nvl(cuo.int_mor_ade,0);
       v_int_punitorio   := nvl(v_int_punitorio,0) + nvl(cuo.int_punitorio,0);

       v_imp_mor_cap     := nvl(v_imp_mor_cap,0) + round(nvl(cuo.int_mor_cap,0) * 5/100, v_redondeo);
       v_imp_mor_int     := nvl(v_imp_mor_int,0) + round(nvl(cuo.int_mor_int,0) * 5/100, v_redondeo);
       v_imp_mor_ade     := nvl(v_imp_mor_ade,0) + round(nvl(cuo.int_mor_ade,0) * 5/100, v_redondeo);
       v_imp_punitorio   := nvl(v_imp_punitorio,0) + round(nvl(cuo.int_punitorio,0) * 5/100, v_redondeo);

       v_impuesto        := nvl(v_impuesto,0) + nvl(cuo.impuesto,0);
       v_cargo           := nvl(v_cargo,0) + nvl(cuo.cargo,0);
       v_iva             := nvl(v_iva,0) + nvl(cuo.iva,0);
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
    -- total cobrado
    v_total := v_mto_cuota +
               v_int_mor_cap + v_int_mor_int + v_int_mor_ade +
               v_int_punitorio +
               v_impuesto +
               v_cargo +
               v_iva ;
    --- Recalcular el moratorio y punitorio + el 5%
    v_int_mor_cap := v_int_mor_cap + v_imp_mor_cap;--round((v_int_mor_cap*5/100),v_redondeo);
    v_int_mor_int := v_int_mor_int + v_imp_mor_int;--round((v_int_mor_int*5/100),v_redondeo);
    v_int_mor_ade := v_int_mor_ade + v_imp_mor_ade;--round((v_int_mor_ade*5/100),v_redondeo);
    v_int_punitorio := v_int_punitorio + v_imp_punitorio;--round((v_int_punitorio*5/100),v_redondeo);

    v_total_cargos :=
               v_int_mor_cap + v_int_mor_int + v_int_mor_ade +
               v_int_punitorio +
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
    if to_number(p_nro_cuenta) > 1000000 then
       pag_imp.pr_imp_linea(v_resultado, 'Prestamo: '||v_nro_cuenta||' ('||p_nro_cuenta||')', 1, 0);
    else
       pag_imp.pr_imp_linea(v_resultado, 'Prestamo: '||p_nro_cuenta, 1, 0);
    end if;

    pag_imp.pr_imp_linea(v_resultado, 'CONCEPTO              MONTO          IMP', 2, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Interes Moratorio: '||to_char(v_int_mor_cap+v_int_mor_int+v_int_mor_ade,'9,999,999,999.99')||'  5%', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Interes Punitorio: '||to_char(v_int_punitorio,'9,999,999,999.99')||'  5%', 1, 0);
--    if fug_obt_tip_implementacion <> 1 then
        pag_imp.pr_imp_linea(v_resultado, 'Gastos Cobranza  : '||to_char(v_cargo+v_iva,'9,999,999,999.99')||' 10%', 1, 0);
/*    else
        pag_imp.pr_imp_linea(v_resultado, 'Gastos Cobranza  : '||to_char(v_cargo+v_iva,'9,999,999,999.99')||'  5%', 1, 0);
    end if;*/
    pag_imp.pr_imp_linea(v_resultado, '                  ------------------', 1, 0);
    -- total
    pag_imp.pr_imp_linea(v_resultado, 'TOTAL       '||rpad(p_cod_moneda,3,' ')||' : '||to_char(v_total_cargos,'9,999,999,999.99'), 1, 0);
    ---
    --pag_imp.pr_imp_linea(v_resultado, 'Son '||fue_obt_denominacion(v_total_cargos), 1, 0);
    v_denominacion := 'Son: '||v_moneda||' '||fue_obt_denominacion(v_total_cargos);
    if length(v_denominacion) > 40 then
       v_hasta :=instr(substr(v_denominacion,1,40),' ',-1);
    else
       v_hasta := length(v_denominacion);
    end if;   
    pag_imp.pr_imp_linea(v_resultado, substr(v_denominacion,1,v_hasta),2,0);
    pag_imp.pr_imp_linea(v_resultado, substr(v_denominacion,v_hasta+1),1,0);

    --- Liquidacion del IVA
    pag_imp.pr_imp_linea(v_resultado, 'Liquidacion del IVA', 2, 0);
--    if fug_obt_tip_implementacion <> 1 then 
      pag_imp.pr_imp_linea(v_resultado, 'I.V.A. 5%           : '||to_char(v_impuesto,'99,999,999,999.99'), 1, 0);
      pag_imp.pr_imp_linea(v_resultado, 'I.V.A. 10%          : '||to_char(v_iva,'99,999,999,999.99'), 1, 0);
/*    else
      pag_imp.pr_imp_linea(v_resultado, 'I.V.A. 5%           : '||to_char((v_impuesto + v_iva),'99,999,999,999.99'), 1, 0);
--      pag_imp.pr_imp_linea(v_resultado, 'I.V.A. 10%          : '||to_char(v_iva,'99,999,999,999.99'), 1, 0);
    end if;
*/    --- Formas de Cobro
    pag_imp.pr_imp_linea(v_resultado, 'FORMAS DE COBRO', 2, 0);
    for pag in c_forma_cob loop
       if pag.cod_transaccion = 572 then
          v_imp_cuenta := pag.monto;
       else
          pag_imp.pr_imp_linea(v_resultado, rpad(pag.descripcion,20,' ')||': '||to_char(pag.monto,'99,999,999,999.99'), 1, 0);
       end if;
    end loop;
    pag_imp.pr_imp_linea(v_resultado, '                      ------------------', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'TOTAL        '||rpad(p_cod_moneda,3,' ')||'    : '||to_char(v_total,'99,999,999,999.99'), 1, 0);
    --impuesto, si corresponde
    if fug_obt_tip_implementacion = 1 and nvl(v_imp_cuenta,0) >0 then
       pag_imp.pr_imp_linea(v_resultado, 'Impuesto Ley 125        : '||to_char(v_imp_cuenta,'99,999,999,999.99'), 1, 0);
    end if;
    --- Detalle de Cheques
    v_vez := 0;
    for che in c_cheques loop
       if v_vez = 0 then
          --- Solo imprimir si hay cheques y la primera vez
          pag_imp.pr_imp_linea(v_resultado, 'DETALLE DE CHEQUES', 2, 0);
          v_vez := 1;
       end if;
       pag_imp.pr_imp_linea(v_resultado, rpad(che.abreviatura||' '||che.nro_cheque,20,' ')||': '||to_char(che.monto,'99,999,999,999.99'), 1, 0);
    end loop;
    -- imprimo el pie
    pag_imp.pr_imp_linea(v_resultado, '----------------------------------------', 1, 0);
    --leyenda
    pag_imp.pr_imp_linea(v_resultado, '----------------------------------------', 11, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Este    formato   esta    aprobado   por', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Constancia de Comunicacion N.05484/05F, ', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'de la Subsecretaria de Estado de Tribu- ', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'tacion de fecha 29/12/2005              ', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Este comprobante segun  esta  Resolucion', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'sirve  para la  utilizacion  del credito', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'fiscal.', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, '*Original: Adquirente', 2, 0);
    pag_imp.pr_imp_linea(v_resultado, '                  *Copia1: Contribuyente', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, '                   *Copia2: Arch.Tribut.', 1, 0);

    pag_imp.pr_imp_pie(v_resultado, 2);   -- linea antes
    v_linea := null;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 10, 0);
  end if;
  --- FIN IMPRESION DE LA FACTURA ---

  return(v_resultado);
end FUJ_IMP_TRANSACCION_360;
/

