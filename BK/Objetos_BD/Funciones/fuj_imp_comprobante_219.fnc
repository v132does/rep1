create or replace function it.FUJ_IMP_COMPROBANTE_219
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
  v_efectivo           ge_movimientos.monto%type; 
  v_des_efectivo       varchar2(1000);  
  v_nstro_bco          ge_movimientos.monto%type;  
  v_des_nstro_bco      varchar2(1000);  
  v_otro_bco           ge_movimientos.monto%type;  
  v_des_otro_bco       varchar2(1000);  
  v_des_servicio       varchar2(1000); 
  v_importador         ge_cob_servicios.referencia1%type;
  v_despachante        ge_cob_servicios.referencia2%type; 
  v_nom_importador     ge_cob_servicios.referencia3%type;
  v_nom_despachante    ge_cob_servicios.referencia4%type;

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
    select c.cod_moneda moneda,
         e.descripcion des_moneda,
         c.monto monto,
         fue_obt_denominacion(c.monto) des_monto,
         c.mto_efectivo efectivo,
         fue_obt_denominacion(c.mto_efectivo) des_mto_efectivo,
         c.mto_che_nue_banco nstro_bco,
         fue_obt_denominacion(c.mto_che_nue_banco) des_nstro_bco,
         c.mto_che_otr_banco otro_bco,
         fue_obt_denominacion(c.mto_che_otr_banco) des_otro_bco,
         b.descripcion des_servicio,
         c.referencia1,
         c.referencia2,
         c.referencia3,
         c.referencia4
    into v_cod_moneda, v_des_moneda, v_monto, v_des_monto,
         v_efectivo, v_des_efectivo, v_nstro_bco, v_des_nstro_bco,
         v_otro_bco, v_des_otro_bco,
         v_des_servicio,
         v_importador,
         v_despachante,
         v_nom_importador,
         v_nom_despachante
    from  ba_monedas e, ge_cob_servicios c, ge_cob_ser_parametros b
   where e.cod_moneda = c.cod_moneda
     and b.cod_servicio = c.cod_servicio
     and c.tip_cobro = 'C'
     and c.nro_caja = p_nro_caja
     and c.nro_operacion = p_nro_operacion
     and exists (select '*'
                   from ge_movimientos z
                  where z.fecha = c.fecha
                    and z.hora = c.hora
                    and z.cod_usuario = c.cod_usuario
                    and z.cod_tra_padre =219
                    and z.nro_documento = p_nro_operacion
                    and z.reversado = 'N'
                    and rownum =1);
  exception
    when no_data_found then
       return(v_resultado);
  end;

  pag_imp.pr_imp_cab_centrada(v_resultado,'*** '||trim(v_des_servicio)||' ***',null,1);
  v_linea := 'Impor/Expor: '||v_importador;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
  v_linea := '             '||v_nom_importador;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);  
  v_linea := 'Despachante: '||v_despachante;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
  v_linea := '             '||v_nom_despachante;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);   

  -- imprimo la fecha y hora
  v_linea := 'Fecha: '||to_char(v_fecha,'dd/mm/yyyy')||'               '||v_hora;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 2);
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
  if nvl(v_efectivo,0) > 0 then
    pag_imp.pr_imp_linea(v_resultado,'Efectivo       : '||v_cod_moneda||' '||lpad(to_char(v_efectivo,'9,999,999,999.99'),20,' '),1);
  end if;
  if nvl(v_nstro_bco,0) > 0 then
    pag_imp.pr_imp_linea(v_resultado,'Cheq.Ntro.Bco  : '||v_cod_moneda||' '||lpad(to_char(v_nstro_bco,'9,999,999,999.99'),20,' '),1);
  end if;
  if nvl(v_otro_bco,0) > 0 then
    pag_imp.pr_imp_linea(v_resultado,'Cheq.Otros Bcos: '||v_cod_moneda||' '||lpad(to_char(v_otro_bco,'9,999,999,999.99'),20,' '),1);
  end if;
  
  pag_imp.pr_imp_linea(v_resultado,'Total Cobrado  : '||v_cod_moneda||' '||lpad(to_char(v_monto,'9,999,999,999.99'),20,' '),2);

  pag_imp.pr_imp_linea(v_resultado,initcap(v_des_moneda)||' '||v_des_monto||'.-',2);


  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',25,'-'),4,0,'S');

  pag_imp.pr_imp_linea(v_resultado,'1.Esta  boleta  para ser valida  debera',2);
  pag_imp.pr_imp_linea(v_resultado,'llevar la firma y sello del cajero.',1);
  pag_imp.pr_imp_linea(v_resultado,'2.El Banco  se  reserva  el  derecho de',1);
  pag_imp.pr_imp_linea(v_resultado,'rectificar todo error que surja de esta',1);
  pag_imp.pr_imp_linea(v_resultado,'transaccion.',1);
  -- imprimo el pie
  pag_imp.pr_imp_pie(v_resultado, 2);   -- linea antes

  v_linea := null;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 8);

  return(v_resultado);
exception
   when others then
      return null;

end FUJ_IMP_COMPROBANTE_219;
/

