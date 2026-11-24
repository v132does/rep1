create or replace function it.FUJ_IMP_COMPROBANTE_300
  (p_nro_operacion in number,
   p_cod_oficina   in number,
   p_nro_caja      in number)
 return varchar2 is
  --comprimido 40 de ancho
  v_ancho          number(3) := 40; -- ancho del reporte
  v_resultado      varchar2(4000) := null;
  v_linea          varchar2(200);
  v_lin_corte      varchar2(200);
  v_lin_ret        varchar2(200);
  v_lin_dep_cuenta varchar2(200);
  v_lin_total      varchar2(200);
  v_lin_oficina    varchar2(200);
  v_lin_cob_varios varchar2(200) default rpad('COB. VARIOS',14,' ')||'  '||lpad('0',3,' ')||'  '||lpad(trim(to_char(0,'999,999,999,999')),15,' ');
  v_concepto       varchar2(20);

  v_fecha          date := SYSDATE;
  v_hora           varchar2(8) := to_char(sysdate,'hh24:mi:ss');
  --
  v_des_ret        ge_retenciones.descripcion%type;
  v_nom_usuario    varchar2(100);
  v_tot_can        number default 0;
  v_tot_imp        number default 0;
  v_imp_dep_cta    number default 0;
  v_imp_cob_varios number default 0;
  v_can_dep_cta    number default 0;
  v_can_cob_varios number default 0;
  v_ok             varchar2(1) default 'N';


  cursor c_dat is
  select c.nro_corte, c.fecha fec_corte,  c.hora, c.concepto, c.nro_caja,
         c.cod_usuario, c.cod_oficina, fue_obt_des_oficina(c.cod_oficina) des_oficina,
         c.cod_retencion,
         fue_obt_nom_usuario(c.cod_usuario) nom_usuario,
         count(*) can_boletas, sum(c.monto) importe
  from (
    select a.fecha,
           case when a.cod_tra_padre in
             (select d.cod_transaccion from ge_gru_transacciones_det d
               where d.cod_transaccion = a.cod_tra_padre
                 and d.cod_gru_transaccion =
                     fug_obt_pardinamico('GRU_DEP_CHE_COB',
                                          9,
                                          91,
                                          a.cod_moneda)) then
             'DEPOSITO EN CUENTA'
           else (
             case when a.cod_tra_padre = 300 then
               'CORTE'
             else
               'COBROS VARIOS'
             end )
           end concepto,
           a.nro_corte,
           (select b.hora from cj_cortes_tmp b
             where b.fecha = a.fecha
               and b.cod_usuario = a.cod_usuario
               and b.nro_caja = a.nro_caja
               and b.nro_corte = a.nro_corte
               and b.cod_tra_padre = 300) hora,
           a.monto,
           a.cod_retencion, a.cod_oficina, a.cod_usuario,
           a.nro_caja, a.nro_secuencia
      from cj_cortes_tmp a ) c
     where c.fecha = pae_cnf.fu_obt_fec_actual(9)
        and c.nro_caja = p_nro_caja
        and c.nro_corte = p_nro_operacion
        and c.cod_oficina = p_cod_oficina
  group by c.nro_corte, c.fecha,  c.hora, c.concepto, c.nro_caja,
           c.cod_usuario, c.cod_oficina, c.cod_oficina, c.cod_retencion,
           c.cod_usuario
  order by 1;

begin
  -- seteo el ancho del reporte
  pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante
  pag_imp.pr_set_oficina(p_cod_oficina);
--  v_resultado := pag_imp.fu_set_impresora(2,'Ubique la hoja en la Impresora');
  pag_imp.pr_imp_cab_centrada(v_resultado,'*** '||'ENTREGA DE DOCUMENTOS'||' ***',null,1);
  for k in c_dat loop
    v_ok := 'S';
    Begin
      Select descripcion
        into v_des_ret
        from ge_retenciones
       where cod_retencion = k.cod_retencion;
    exception
      when no_data_found then
        null;
      when others then
        Null;
    end;
    --imprimo la fecha y hora del Corte
    v_lin_oficina := 'Oficina: '||k.cod_oficina||'-'||fue_obt_des_oficina(k.cod_oficina);

    v_lin_corte := 'Corte:   '||to_char(k.fec_corte,'dd/mm/yyyy')||' '||k.hora;

    v_lin_ret := ('Ret.:    '||k.cod_retencion||'-'||trim(rpad(v_des_ret,29,' ')));

    if k.concepto = 'DEPOSITO EN CUENTA' then
      --v_concepto := 'DEP. EN CUENTA';
      --v_lin_dep_cuenta := rpad(v_concepto,14,' ')||'  '||lpad(k.can_boletas,3,' ')||'  '||lpad(trim(to_char(k.importe,'999,999,999,999')),15,' ');
      v_can_dep_cta := nvl(v_can_dep_cta,0) + k.can_boletas;
      v_imp_dep_cta := nvl(v_imp_dep_cta,0) + k.importe;
    elsif k.concepto = 'COBROS VARIOS' then
      --v_concepto := 'COB. VARIOS';
      --v_lin_cob_varios := rpad(v_concepto,14,' ')||'  '||lpad(k.can_boletas,3,' ')||'  '||lpad(trim(to_char(k.importe,'999,999,999,999')),15,' ');
      v_can_cob_varios := nvl(v_can_cob_varios,0) + k.can_boletas;
      v_imp_cob_varios := nvl(v_imp_cob_varios,0) + k.importe;    
    end if;

    v_tot_can := v_tot_can + k.can_boletas;
    v_tot_imp := v_tot_imp + k.importe;

  end loop;

  if v_ok = 'S' then

  v_linea := 'Fecha:   '||to_char(v_fecha,'dd/mm/yyyy')||'             '||v_hora;
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);

  pag_imp.pr_imp_linea(v_resultado, v_lin_oficina, 1);

  -- Imprimo datos del cajero --ver si el usuario del movimiento = al del mov. de caja
  v_nom_usuario :=fue_obt_nom_usuario(user);
  v_linea := 'Caja:    '||rpad(p_nro_caja,4,' ')||rpad(v_nom_usuario,30,' ');
  pag_imp.pr_imp_linea(v_resultado, v_linea, 1);

  pag_imp.pr_imp_linea(v_resultado,v_lin_corte,1);
  pag_imp.pr_imp_linea(v_resultado,v_lin_ret,1);

  pag_imp.pr_imp_linea(v_resultado, null, 1);
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
  -- titulos detalle
  pag_imp.pr_imp_linea(v_resultado,'Cheques C/O/B    Can.        Importe',1);
  -- detalle
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);

  v_lin_dep_cuenta := rpad('DEP. EN CUENTA',14,' ')||'  '||lpad(v_can_dep_cta,3,' ')||'  '||lpad(trim(to_char(v_imp_dep_cta,'999,999,999,999')),15,' ');
  pag_imp.pr_imp_linea(v_resultado,v_lin_dep_cuenta,1);
  
  v_lin_cob_varios := rpad('COB. VARIOS',14,' ')||'  '||lpad(v_can_cob_varios,3,' ')||'  '||lpad(trim(to_char(v_imp_cob_varios,'999,999,999,999')),15,' ');
  pag_imp.pr_imp_linea(v_resultado,v_lin_cob_varios,1);

  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);
  v_tot_can := v_tot_can - 1;
  v_lin_total := lpad('TOTAL',14,' ')||'  '||lpad(v_tot_can,3,' ')||'  '||lpad(trim(to_char(v_tot_imp,'999,999,999,999')),15,' ');
  pag_imp.pr_imp_linea(v_resultado,v_lin_total,1);

  -- fin detalle
  pag_imp.pr_imp_linea(v_resultado, null, 3);
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',25,'-'),4,0,'S');
  pag_imp.pr_imp_linea(v_resultado,'       Sello y Firma del Cajero',1);
  -- linea fin
  pag_imp.pr_imp_linea(v_resultado, null, 2);
  pag_imp.PR_IMP_LINEA(v_resultado,lpad('-',40,'-'),1);

  end if;
  return(v_resultado);
exception
   when others then
      return sqlerrm;

end FUJ_IMP_COMPROBANTE_300;
/

