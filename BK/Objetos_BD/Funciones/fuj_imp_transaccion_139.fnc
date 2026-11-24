create or replace function it.FUJ_IMP_TRANSACCION_139
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
  v_monto number(18,2);
  v_int_mor_cap number(18,2);
  v_int_mor_int number(18,2);
  v_int_mor_ade number(18,2);
  v_int_punitorio number(18,2);
  v_impuesto number(18,2);
  v_cargo number(18,2);
  v_iva number(18,2);
  v_total number(18,2);
  --v_total_cargos number(18,2);
  v_nro_impresion number(10);
  v_nro_cuenta pr_cta_prestamos.nro_cuenta%type;
  v_cod_usuario ba_usuarios.cod_usuario%type;
  v_hasta number;
  v_denominacion varchar2(4000);
  v_moneda ba_monedas.descripcion%type;
  v_redondeo number(2) := 0;
  v_imp_cuenta number(18,2);
  v_ind_cheque varchar2(1) := 'N';
  --- Cursor de cuotas cobradas
  cursor c_ctas_cob is
  select c.cod_persona , c.nom_completo, c.nro_documento,
         nvl(a.mto_total,0) monto,
         nvl(a.mto_int_moratorio,0)  int_mor_cap,
         nvl(a.mto_int_punitorio,0) int_punitorio,
         nvl(a.mto_impuesto,0) impuesto,
         nvl(a.mto_cargo,0)-nvl(a.mto_cargo_iva,0) cargo,
         nvl(a.mto_cargo_iva,0) iva,
         p.fec_apertura
   from ba_personas c, ge_cta_clientes b, ov_cobros a, ov_cta_vencidas p
   where a.nro_cuenta = b.nro_cuenta
     and p.nro_cuenta = a.nro_cuenta
     and b.relacion = 'P' -- cliente principal
     and c.cod_persona = b.cod_persona
     and a.nro_cuenta = p_nro_cuenta
     and a.fecha = p_fecha
     and a.hora = p_hora;
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
  If p_cod_moneda != pag_gen.fu_obt_mon_local then
     v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6);
  End if;
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
       select distinct cod_usuario
         into v_cod_usuario
         from cj_movimientos
        where nro_documento = p_nro_operacion
          and cod_tra_padre in (139);
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
    v_monto     := 0;
    v_int_mor_cap   := 0;
    v_int_mor_int   := 0;
    v_int_mor_ade   := 0;
    v_int_punitorio := 0;
    v_impuesto      := 0;
    v_cargo         := 0;
    v_iva           := 0;
    for ope in c_ctas_cob loop
       v_cod_persona     := ope.cod_persona;
       v_nom_completo    := ope.nom_completo;
       v_nro_documento   := ope.nro_documento;
       v_fec_vencimiento := ope.fec_apertura;
       v_monto       := nvl(v_monto,0) + nvl(ope.monto,0);
       v_int_mor_cap     := nvl(v_int_mor_cap,0) + nvl(ope.int_mor_cap,0);
       v_int_punitorio   := nvl(v_int_punitorio,0) + nvl(ope.int_punitorio,0);

       v_impuesto        := nvl(v_impuesto,0) + nvl(ope.impuesto,0);
       v_cargo           := nvl(v_cargo,0) + nvl(ope.cargo,0);
       v_iva             := nvl(v_iva,0) + nvl(ope.iva,0);
    end loop;
    -- total cobrado
    v_total := v_monto +
               v_int_mor_cap + v_int_mor_int + v_int_mor_ade +
               v_int_punitorio +
               v_impuesto +
               v_cargo +
               v_iva ;
  If v_total != 0 then
    pag_imp.pr_imp_cab_centrada(v_resultado,  -- texto
                             '*** PAGO DE OP.VENCIDA ***',  -- titulo
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

    -- total cobrado
    v_total := v_monto +
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
       pag_imp.pr_imp_linea(v_resultado, 'Operacion: '||v_nro_cuenta||' ('||p_nro_cuenta||')', 1, 0);
    else
       pag_imp.pr_imp_linea(v_resultado, 'Operacion: '||p_nro_cuenta, 1, 0);
    end if;
    pag_imp.pr_imp_linea(v_resultado, 'Recibimos  el  Pago  en  concepto  de su', 2, 0,'S');
    pag_imp.pr_imp_linea(v_resultado, 'Operacion arriba indicada, segun detalle', 1, 0,'S');
    -- detalle de los cobros
    pag_imp.pr_imp_linea(v_resultado, 'Fecha de Vencimiento: '||to_char(v_fec_vencimiento,'dd/mm/yy'), 2, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Monto               : '||to_char(v_monto,'99,999,999,999.99'), 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Interes Moratorio   : '||to_char(v_int_mor_cap+v_int_mor_int+v_int_mor_ade,'99,999,999,999.99'), 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Interes Punitorio   : '||to_char(v_int_punitorio,'99,999,999,999.99'), 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Gastos Cobranza     : '||to_char(v_cargo+v_iva,  '99,999,999,999.99'), 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Impuesto            : '||to_char(v_impuesto,'99,999,999,999.99'), 1, 0);
    --- Letras del monto pagado
    v_denominacion := 'Son: '||v_moneda||' '||fue_obt_denominacion(v_total);
    if length(v_denominacion) > 40 then
       v_hasta :=instr(substr(v_denominacion,1,40),' ',-1);
    else
       v_hasta := length(v_denominacion);
    end if;
    pag_imp.pr_imp_linea(v_resultado, substr(v_denominacion,1,v_hasta),2,0);
    pag_imp.pr_imp_linea(v_resultado, substr(v_denominacion,v_hasta+1),1,0);

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
    pag_imp.pr_imp_pie(v_resultado, 2);   -- linea antes
    v_linea := null;
    pag_imp.pr_imp_linea(v_resultado, v_linea, 10, 0);
  end if;
  --- FIN IMPRESION DEL RECIBO ---
 End If;

  return(v_resultado);
end FUJ_IMP_TRANSACCION_139;
/

