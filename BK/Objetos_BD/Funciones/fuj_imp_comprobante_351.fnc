create or replace function it.FUJ_IMP_COMPROBANTE_351
  (p_nro_operacion in number,
   p_cod_oficina   in number,
   p_nro_caja      in number)
 return varchar2 is
  --comprimido 40 de ancho
  v_ancho     	 	 number(3) := 40; -- ancho del reporte
  v_resultado 		 varchar2(4000) := null;
  v_linea     		 varchar2(200);
  v_fecha          date := SYSDATE;
  v_hora           varchar2(8) := to_char(sysdate,'hh24:mi:ss');
  v_col_antes      number;
  --
  v_nro_cuenta      varchar2(15);
  v_cta_formateada  varchar2(20);
  v_denominacion    varchar2(100);
  v_des_modalidad   varchar2(100);
  v_cod_moneda      varchar2(4);
  v_des_moneda      varchar2(100);
  v_monto           number(18,2);
  v_des_monto       varchar2(300);
  v_des_transaccion varchar2(200);
  --
  v_nro_impresion      number(10);
  v_cod_tip_ope_cambio varchar2(6);
  v_des_tip_operacion  varchar2(100);
  v_nom_usuario        varchar2(100);
  v_cod_ope_bcp        varchar2(6);
  v_des_ope_bcp        varchar2(100);
  v_referencia         varchar2(20);
  v_cotizacion         ge_cotizaciones.val_conversion%type;
  v_mto_equ_local      number(18);
  v_cta_cambios        varchar2(20);
  v_nro_documento      varchar2(20);
  v_nom_persona        varchar2(200);
  v_importe            number;
  v_una_vez            varchar2(1) :='S';
  v_cod_usuario        varchar2(10);
  v_sigla              ge_bancos.sigla%type;
  v_nro_documento3     ge_movimientos.nro_documento3%type;
  v_nombre             varchar2(40);

begin
  -- seteo la oficina
  pag_imp.pr_set_oficina(p_cod_oficina);
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
  --imprimir nro de impresion, x ahora no se enumeran
  v_nro_impresion := 0;
  Begin
    Select nvl(count(*),0)+1
      into v_nro_impresion
      from cj_movimientos
     where cod_tra_padre = 110
       and cod_mod_padre = 9
       and cod_mad_padre = 91
       and nro_documento = p_nro_operacion;
  End;
  begin
    select c.nro_cuenta cuenta,
         fug_cta_formateada(c.cod_modulo,c.cod_modalidad,c.cod_oficina,c.nro_cuenta,
         c.cod_moneda,c.dig_verificador) cta_formateada,
         c.denominacion denominacion,
         a.cod_moneda moneda,
         e.descripcion des_moneda,
         a.monto monto,
         fue_obt_denominacion(monto) des_monto,
         f.descripcion,
         d.descripcion
    into v_nro_cuenta, v_cta_formateada, v_denominacion,
         v_cod_moneda, v_des_moneda, v_monto, v_des_monto,
         v_des_transaccion, v_des_modalidad
    from ge_transacciones f, ba_monedas e, ge_modalidades d, ge_cuentas c, ge_movimientos a
   where a.nro_cuenta = c.nro_cuenta
     and d.cod_modulo = c.cod_modulo
     and d.cod_modalidad = c.cod_modalidad
     and e.cod_moneda = a.cod_moneda
     and a.estado = 'N'
     and a.nro_documento = p_nro_operacion
     and a.cod_tra_padre in (351,352)
 --    and a.cod_transaccion in (632,690)
     and a.reversado = 'N'
     and f.cod_modulo = a.cod_mod_padre
     and f.cod_modalidad = a.cod_mad_padre
     and f.cod_transaccion = a.cod_tra_padre
     and not exists (select 'S'
                       from ge_movimientos mo
                      where mo.estado = 'N'
                        and mo.cod_tra_padre = 351
                        and mo.cod_transaccion = 606
                        and mo.reversado = 'N'
                        and mo.nro_documento = a.nro_documento) ;
  exception
    when no_data_found then
       return(v_resultado);
  end;
 -- v_resultado := pag_imp.fu_set_impresora(2,'Ubique la hoja en la Impresora');
  pag_imp.pr_imp_cab_centrada(v_resultado,'*** '||'DEPOSITO EN EFECTIVO'||' ***',null,1);

  -- imprimo la fecha y hora
  v_linea := 'Fecha: '||to_char(v_fecha,'dd/mm/yyyy')||'               '||v_hora;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
  -- Imprimo datos del cajero --ver si el usuario del movimiento = al del mov. de caja
  v_nom_usuario :=fue_obt_nom_usuario(user);
  if fug_obt_tip_implementacion = 1 then
    v_linea := 'Caja: '||rpad(p_nro_caja,4,' ');--||lpad(v_nom_usuario,30,' ');
  else
    v_linea := 'Caja: '||rpad(p_nro_caja,4,' ')||lpad(v_nom_usuario,30,' ');
  end if;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);


  --imprimo nro operacion
  if v_nro_impresion = 0 then
    v_linea := 'Numero: '||rpad(p_nro_operacion,8,' ')||'                '||'Original';
    pag_imp.pr_imp_linea(v_resultado,v_linea,1);
  else
    v_linea := 'Numero: '||rpad(p_nro_operacion,8,' ')||'       '||'Copia Nro.: '||lpad(v_nro_impresion,5,' ');
    pag_imp.pr_imp_linea(v_resultado,v_linea,1);
  end if;

  -- detalle de la operacion
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
  -- Datos de la Cuenta
  pag_imp.pr_imp_linea(v_resultado,'Cuenta  Nro: ',1);
  pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita
  pag_imp.pr_imp_linea(v_resultado,v_cta_formateada);
  pag_imp.pr_negrita(v_resultado,'N'); -- Apaga negrita
  pag_imp.pr_imp_linea(v_resultado,'A Nombre de: '||v_denominacion,1);
  pag_imp.pr_imp_linea(v_resultado,'Tipo de Cta: '||v_des_modalidad,1);
  pag_imp.pr_imp_linea(v_resultado,'Moneda     : '||v_des_moneda,1);

  pag_imp.pr_imp_linea(v_resultado,'Efectivo   : '||v_cod_moneda||' '||lpad(to_char(v_monto,'999,999,999,999.99'),23,' '),2);

  pag_imp.pr_imp_linea(v_resultado,initcap(v_des_moneda)||' '||v_des_monto||'.-',2);

  pag_imp.pr_imp_linea(v_resultado,'1. Esta  boleta  para ser valida  debera',2);
  pag_imp.pr_imp_linea(v_resultado,'llevar la firma y sello del cajero.',1);
  pag_imp.pr_imp_linea(v_resultado,'2. El Banco  se  reserva  el  derecho de',1);
  pag_imp.pr_imp_linea(v_resultado,'rectificar  todo error que surja de este',1);
  pag_imp.pr_imp_linea(v_resultado,'deposito.',1);
  pag_imp.pr_imp_linea(v_resultado,'3. Favor  verifique  que el Nro. de Cta.',1);
  pag_imp.pr_imp_linea(v_resultado,'y el titular de la misma sean correctos.',1);
  pag_imp.pr_imp_linea(v_resultado,'El Banco  no  se responsabiliza por con-',1);
  pag_imp.pr_imp_linea(v_resultado,'secuencias  que  errores  en uno o ambos',1);
  pag_imp.pr_imp_linea(v_resultado,'datos pudieran ocasionar.',1);

  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',25,'-'),4,0,'S');
  pag_imp.pr_imp_linea(v_resultado,'Firma del Depositante C.I.:',1,0,'S');

  -- imprimo el pie
  pag_imp.pr_imp_pie(v_resultado, 2);   -- linea antes

  v_linea := null;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 8);

  return(v_resultado);
exception
   when others then
      return null;

end FUJ_IMP_COMPROBANTE_351;

 
/
