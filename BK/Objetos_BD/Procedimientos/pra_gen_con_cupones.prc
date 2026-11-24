CREATE OR REPLACE PROCEDURE IT.PRA_GEN_CON_CUPONES is
-- Proceso que genera Contabilización de Cupones.
-- Se anuló en el trigger TB_AH_CTA_CERTIFICADOS 11/12/2009 V.O.
  cursor c_ctas is
  select *
     from ah_cta_certificados a
    where a.cod_modulo = 3
      and a.cod_modalidad in (33,34,35,36)
      and (
          (a.estado = 'N' and a.fec_cam_estado = pae_cnf.fu_obt_fec_actual(a.Cod_Modulo)) 
         or 
          (a.estado in ('P','C')  and a.fec_apertura   = pae_cnf.fu_obt_fec_actual(a.Cod_Modulo))
          )
      and a.sal_total = a.capital
      and exists (select 1 from ge_movimientos b
                   where b.nro_cuenta = a.nro_cuenta
                     and b.reversado = 'N'
                     and b.cod_transaccion = 425
                     and b.est_cuenta = 'N'
                     );


  cursor c_cup(p_nro_cuenta ge_cuentas.nro_cuenta%type) is
   select sum(mto_interes) mto_interes
     from ah_cupones
    where nro_cuenta = p_nro_cuenta;
     
    
  v_nro_secuencia   ge_movimientos.nro_secuencia%type;
  v_fec_actual      ge_calendarios.fec_actual%type;
  v_hora            ge_movimientos.hora%type;
  r_gmovi           ge_movimientos%rowtype;
  
  
begin
  BEGIN
    -- RABP-CNF-16-09-2014: Se modifica la logica de obtencion de hora y secuencia.
    v_fec_actual    := pae_cnf.fu_obt_fec_actual(3);
    v_hora          := to_char(sysdate,'HH24:MI:SS');
    --Jira 1399: Se cambia la ubicacion de la funcion fug_obt_hor_disponible para obtimizar la utilizacion de la hora
    v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
    v_nro_secuencia := 0;
    for k in c_ctas loop
      pag_cta.pr_obt_cuenta(k.nro_cuenta);
      -- RABP-CNF-16-09-2014: Se modifica la logica de obtencion de hora
      -- v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
    
      for i in c_cup(k.nro_cuenta) loop
        -- RABP-CNF-16-09-2014: Se modifica la logica de suma de secuencia para que no haya desboradamiento.
        if nvl(v_nro_secuencia, 1) >= 995 then

          v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
          v_nro_secuencia := 1;
        else
          v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
        end if;
        --
        r_gmovi.cod_usuario       := user;
        r_gmovi.hora              := v_hora;
        r_gmovi.nro_secuencia     := v_nro_secuencia;
        r_gmovi.cod_mod_padre     := k.cod_modulo;
        r_gmovi.cod_mad_padre     := k.cod_modalidad;
        r_gmovi.cod_modulo        := k.cod_modulo;
        r_gmovi.cod_modalidad     := k.cod_modalidad;
        r_gmovi.cod_oficina       := k.cod_oficina;
        r_gmovi.nro_cuenta        := k.nro_cuenta;
        r_gmovi.cod_moneda        := k.cod_moneda;
        r_gmovi.cod_tra_padre     := 400;
        r_gmovi.cod_transaccion   := 400;
        --r_gmovi.est_cuenta        := 'C';
        r_gmovi.estado            := 'N';
        r_gmovi.reversado         := 'N';
        r_gmovi.emi_aviso         := 'N';
        r_gmovi.protegido         := 'N';
        --r_gmovi.nro_documento     := reg.nro_cupon;
        r_gmovi.monto             := i.mto_interes;
        r_gmovi.cod_ofi_origen    := k.cod_oficina;
        r_gmovi.fecha             := v_fec_actual;
        r_gmovi.fec_valor         := v_fec_actual;
        r_gmovi.concepto          := 'Generacion Contable de Cupones';
        pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
        --
      end loop;
    end loop;
  EXCEPTION
    when others then
      raise_application_error(-20000,'Al contabilizar cup.'||sqlerrm);
  END;
end;
/
