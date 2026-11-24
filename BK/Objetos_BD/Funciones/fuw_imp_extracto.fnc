create or replace function it.FUW_IMP_EXTRACTO
  (p_cod_persona in varchar2,
   p_nro_cuenta  in varchar2 default null)
 return long is
  --comprimido 40 de ancho
  v_ancho     	 	 number(3) := 120; -- ancho del reporte
  v_resultado 		 long := null;
  v_linea     		 varchar2(200);
  v_fecha          date := pag_cal.FU_OBT_FEC_ACTUAL(9);
  v_hora           varchar2(8) := to_char(sysdate,'hh24:mi:ss');
  v_cod_moneda      varchar2(4);
  v_des_moneda      varchar2(100);
  v_monto           number(18,2);
  v_des_monto       varchar2(300);
  v_nro_impresion       number(10);
  v_cod_usuario     ba_usuarios.cod_usuario%type;
  v_nro_caj_destino     cj_cajas.nro_caja%type;
  v_cod_usu_destino     ba_usuarios.cod_usuario%type;
  v_nom_cliente       ge_ext_clientes.nom_cliente%type;
  v_direccion         ge_ext_clientes.direccion%type;
  v_sal_actual        number(18,2);

  
cursor cuentas is 
   select a.nro_cuenta, b.denominacion,a.cod_modalidad, fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_modalidad,
          a.cod_oficina, fue_obt_des_oficina(a.cod_oficina) des_oficina,
          a.cod_moneda,a.sal_anterior,
          a.sal_actual, a.sal_a_confirmar, fue_obt_des_moneda(a.cod_moneda) des_moneda
     from ge_cuentas b, ge_ext_cli_cuentas_tmp a
    where a.cod_persona = p_cod_persona
       and trunc(a.fec_insercion) = trunc(sysdate)
       and a.usu_insercion = user
       and a.nro_cuenta = b.nro_cuenta;

cursor movimientos(p_nro_cuenta in varchar2) is
select e.cod_persona de_cdclien,
      e.cod_extracto de_cdextra,
      e.fec_extracto de_fcextra,
      e.nro_cuenta de_nrcuent,
      to_number(e.nro_cuenta) cta,
      to_char( nvl( e.fec_movimiento, sysdate ), 'dd/mm' ) movim,
      to_char( nvl( e.fec_valor, sysdate ), 'DD/MM' ) VALOR,
      e.nro_documento docum,
      e.cod_tra_padre tranp,
      substr(fue_obt_titulo( t.descripcion ),1,33) nmtrans,
      e.mto_debito debito,
      e.mto_credito credito,
      lower( substr( rutina1, 1, 7 ) ) ruti1,
      greatest( e.fec_movimiento, e.fec_valor ) fecha,
      e.nro_secuencia secuen,
      e.cod_ofi_origen,
      e.cod_modulo,
      rownum registro,
e.fec_insercion
 , TO_DATE(E.HOR_MOVIMIENTO,'HH24:MI:SS') HOR_ORDEN
 from ge_transacciones t, ge_ext_cli_movimientos_tmp e
where t.cod_modulo = e.cod_modulo
  and t.cod_modalidad = e.cod_modalidad
  and t.cod_transaccion = e.cod_tra_padre
  and e.cod_persona = p_cod_persona
  and e.nro_cuenta = p_nro_cuenta
  --and trunc(e.fec_insercion) = trunc(sysdate)
  and e.usu_insercion = user  
order by e.fec_insercion;
 


   
function lf_for_monto(p_monto in number) 
  return varchar2 is
v_retorno varchar2(30);
begin
    v_retorno := lpad(to_char(nvl(p_monto,0),'999G999G999G999G990D00'),23,' ');
    return v_retorno;
end;    
  
begin
  -- genero el extracto temporal
  prg_gen_extracto_tmp(p_cod_persona, p_nro_cuenta);
  -- seteo la oficina
  pag_imp.pr_set_oficina(fug_obt_ofi_cliente(p_cod_persona));
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
 begin
    select nom_cliente, direccion
      into v_nom_cliente, v_direccion
      FROM ge_ext_clientes_tmp
     where cod_persona = p_cod_persona
       and trunc(fec_insercion) = trunc(sysdate)
       and usu_insercion = user;
  exception
    when no_data_found then
       raise_application_error(-20000,'Extracto inexistente');
  end;

  v_des_monto := fue_obt_denominacion(v_monto);
  pag_imp.PR_IMP_CAB_AJUSTADA(v_resultado,'','',1);
  
  v_linea := 'Cliente  : '||p_cod_persona||' '||v_nom_cliente;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);  
  v_linea := 'Direccion: '||v_direccion;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);
  
  for ct in cuentas loop
    
    v_linea := 'Cuenta  : '||rpad(ct.nro_cuenta||' '||ct.denominacion,62,' ')||'  Saldo Anterior       : '||lf_for_monto(ct.sal_anterior);
    pag_imp.pr_imp_linea(v_resultado, v_linea, 2);

    v_linea := 'Tipo    : '||rpad(ct.des_modalidad,62,' ')                   ||'  Saldo Actual         : '||lf_for_monto(ct.sal_actual);
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1);   
    
    v_linea := 'Moneda  : '||rpad(ct.des_moneda,62,' ')                      ||'  Depositos a Confirmar: '||lf_for_monto(ct.sal_a_confirmar);
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1);      
    

    v_linea := 'DIA  NUMERO     CONCEPTO                                            DEBE                   HABER                   SALDO';
    pag_imp.pr_imp_linea(v_resultado, v_linea, 2);   
    v_linea := lpad('-',v_ancho,'-');
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1);     
 
    v_linea := 'SALDO ANTERIOR                                                                                   '||lf_for_monto(ct.sal_anterior);
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1);     
    
    v_sal_actual := nvl(ct.sal_anterior,0);
    -- movimientos
    for mv in movimientos(ct.nro_cuenta) loop


      if mv.debito <> 0 then
         v_sal_actual := v_sal_actual - mv.debito;
      elsif mv.credito <> 0 then
         v_sal_actual := v_sal_actual + mv.credito;
      end if;      
      v_linea := mv.movim||' '||rpad(nvl(to_char(mv.docum),' '),10,' ')||rpad(nvl(mv.nmtrans,' '),33,' ')||lf_for_monto(mv.debito)||' '||lf_for_monto(mv.credito)||' '||lf_for_monto(v_sal_actual);
      pag_imp.pr_imp_linea(v_resultado, v_linea, 1);     
 
      
    end loop; 
    v_linea := lpad('-',v_ancho,'-');
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1);        
    v_linea := 'SALDO ACTUAL                                                                                     '||lf_for_monto(ct.sal_actual);
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1); 
    v_linea := lpad('-',v_ancho,'-');
    pag_imp.pr_imp_linea(v_resultado, v_linea, 1);               
  
  end loop; 
    

  return(REPLACE(v_resultado,'~',''));

end FUW_IMP_EXTRACTO;
/

