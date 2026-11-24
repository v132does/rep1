create or replace procedure it.prt_cal_pag_est_tar_gp
                                                    (p_nro_cuenta in ta_tarjetas.nro_cuenta%type,
                                                     p_por_int  in number,
                                                     p_saldo_periodo in number,
                                                     p_pago_minimo in number,
                                                     p_monto_final out number,
                                                     p_meses out number,
                                                     p_cod_error   out number,
                                                     p_men_error   out varchar2) is
    v_nom_programa varchar2(50) := 'IT.PRT_CAL_PAG_EST_TAR_GP';
    p_sal_deuda number(18,3) := p_saldo_periodo;
    p_sal_pago number(18,3) := 0;
    p_interes number(18,3) := 0;
    p_calculo number(18,3) := 0;
    pcont number(5) :=0;
begin
  while p_sal_pago != p_sal_deuda loop
    pcont:= pcont+1;

    if p_sal_deuda > p_pago_minimo then
       p_sal_pago := p_sal_deuda - p_pago_minimo;
    else
       p_sal_pago := p_sal_deuda;
    end if;
    p_calculo := round(p_sal_pago*(p_por_int/100)/365*30);
    if nvl(p_calculo,0) > 0 then
      p_interes := nvl(p_interes,0) + p_calculo;
    end if;
    if  p_sal_pago != p_sal_deuda then
        p_sal_deuda := p_sal_pago + p_calculo;
    end if;
  end loop;
  
  if p_interes!=0 and pcont!=0  then
      p_monto_final:=p_interes+p_saldo_periodo;
      p_meses:=pcont;
      p_cod_error := nvl(fug_obt_pardinamico('COD_MSG_EXITO'), 200);
      p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),'Transaccion Exitosa!');                    
   else
      p_cod_error := nvl(fug_obt_pardinamico('COD_ERR_SQL'),999);
      p_men_error := 'Error en los calculos';
      p_monto_final:=0;
      p_meses:=0;
      prg_ins_log_programas(v_nom_programa,substr
      ('Error al calcular el pago estimado!Nro. de cuenta: '||p_nro_cuenta,1,4000));
   end if;
end;
/

