create or replace procedure it.prp_des_atm_prestamo_res_04(p_cod_persona   in varchar2,
                                                 p_monto         in number,
                                                 p_cta_credito   in varchar2,
                                                 p_nro_solicitud in varchar2,
                                                 p_nro_cta_anterior in varchar2,
                                                 p_nro_cta_generada out varchar2,
                                                 p_hora out varchar2) is

  v_fecha         date := pag_cal.fu_obt_fec_actual(6);
  v_est_modulo ba_modulos.estado%TYPE := pae_cnf.fu_obt_est_modulo(6);
  v_hora          ge_movimientos.hora%type := to_char(sysdate, 'hh24:mi:ss');
  v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
  v_nro_cuenta    ge_cuentas.nro_cuenta%type;
  rg_solicitudes  pr_solicitudes%rowtype;
  v_usuario       ba_usuarios.cod_usuario%type;
  v_es_nocturno   varchar2(1) default 'N';
  v_horario       varchar2(1) default 'D';
  v_cod_rubro_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_RES_04',null,null,'GS', null,null);
  v_cod_rubro_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_RES_04',null,null,'USD', null,null);
  v_cod_rubro     varchar2(100);
  r_gmovi         ge_movimientos%rowtype;
  v_lugar  varchar2(3000);
begin
  --Verificar Usuario ATM--
  if substr(user,1,3) = 'ATM' then
     v_usuario := fug_obt_pardinamico('COD_USU_ATM_ACTUAL');
     v_est_modulo := pae_cnf.fu_obt_est_modulo(3); -- CORECTRB-2 ABR/2018
   else
     v_usuario := user;
  end if;

  v_lugar:='Obteniendo datos Sol:'||p_nro_solicitud||' Persona: '||p_cod_persona;

  begin
    select *
      into rg_solicitudes
      from pr_solicitudes a
     where a.nro_solicitud = p_nro_solicitud;
  exception
    when no_data_found then
      Raise_application_error(-20000, 'No se encuentra la Solicitud de Préstamo!');
    when too_many_rows then
      Raise_application_error(-20000, 'Se recupera más de una Solicitud de Préstamo Pendiente!');
  end;
  -- PCCDEEVO-214 Oferta Pre Aprobados en Cierre 06/2017.
  If v_est_modulo = 2 then
     v_es_nocturno := 'N';
     v_horario     := 'D' ;    -- D=Abierto, N=Cerrado
  else
     v_es_nocturno := 'S';
     v_horario     := 'N' ;    -- D=Abierto, N=Cerrado
     v_fecha       := pag_cal.fu_obt_fec_proxima(6);
  end if;
  --obtenermos la hora disponible
  v_hora := fug_obt_hor_disponible(v_fecha,v_hora,v_usuario,v_es_nocturno);
  --valida que este todo ok antes del desembolso, luego genera la cuenta
  v_lugar:='Desembolsando Prestamo Sol:'||p_nro_solicitud||' Persona: '||p_cod_persona;
  pap_pre_res_04.PR_DES_PRESTAMOS(rg_solicitudes.nro_solicitud,
                           rg_solicitudes.tot_desembolsar,
                           rg_solicitudes.fec_inicio,
                           rg_solicitudes.tip_documento,
                           1,
                           1,
                           rg_solicitudes.cod_oficina,
                           rg_solicitudes.cod_ori_fondo,
                           v_hora,
                           v_nro_secuencia,
                           v_nro_cuenta); --out


  --DYDMR-5803--Modificado por rpavon 03.01.17--
  if v_nro_cuenta is not null then
        --Setear variables para cargar usuario correcto--
        PAG_CTA.PR_SET_VARIABLES(v_usuario,
                                 v_fecha,
                                 358,
                                 'N',-- estado
                                 'N',-- reversado
                                 v_nro_secuencia,
                                 null,
                                 rg_solicitudes.cod_oficina,
                                 rg_solicitudes.cod_modulo,
                                 rg_solicitudes.cod_modalidad);

        -- Actualiza el horario del pag_cta según estado del modulo -- PCCDEEVO-214 06/2017
        pag_cta.g_horario := v_horario;
        --acreditacion a la cuenta
        --Se debe acreditar a la cuenta contable
       /* pag_cta.PR_ACT_OPERACION(p_cta_credito,
                                 v_hora,
                                 'C', --credito
                                 rg_solicitudes.cod_moneda,
                                 rg_solicitudes.tot_desembolsar,
                                 358,
                                 602,
                                 rg_solicitudes.nro_solicitud,
                                 v_cotizacion,
                                 rg_solicitudes.cod_oficina,
                                 rg_solicitudes.cod_modulo,
                                 rg_solicitudes.cod_modalidad,
                                 null,
                                 null,
                                 'Desembolso de Sol. ' ||
                                 rg_solicitudes.nro_solicitud,
                                 'S', --emi_aviso
                                 v_nro_secuencia,
                                 v_fecha);*/

          if rg_solicitudes.cod_moneda=pag_gen.FU_OBT_MON_LOCAL then
            v_cod_rubro:= v_cod_rubro_gs;
          else
              v_cod_rubro:= v_cod_rubro_usd;
          end if;
          v_lugar:='Actualizando Cuenta Contable Prestamo-Sol:'||p_nro_solicitud||' Persona: '||p_cod_persona;
         --WA: Actualizamos contra Cuenta contable
           if v_cod_rubro is not null then
               r_gmovi.cod_usuario     := user;
               r_gmovi.hora            := v_hora;
               r_gmovi.fecha           := v_fecha;
               -- Aumento la secuencia
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               --
               r_gmovi.cod_modulo      := rg_solicitudes.cod_modulo;
               r_gmovi.cod_modalidad   := rg_solicitudes.cod_modalidad;
               r_gmovi.cod_oficina     := rg_solicitudes.cod_oficina;
               r_gmovi.cod_moneda      := rg_solicitudes.cod_moneda;
               r_gmovi.fec_valor       := v_fecha;
               r_gmovi.cod_tra_padre   := 358;
               r_gmovi.cod_mod_padre   := rg_solicitudes.cod_modulo;
               r_gmovi.cod_mad_padre   := rg_solicitudes.cod_modalidad;
               r_gmovi.cod_transaccion := 741;
               r_gmovi.monto           := rg_solicitudes.monto;
               r_gmovi.nro_documento   := rg_solicitudes.nro_solicitud;
               r_gmovi.cod_ofi_origen  := rg_solicitudes.cod_oficina;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := 'Desembolso de Solicitud'||rg_solicitudes.nro_solicitud;
                r_gmovi.estado          := 'N'; -- movimiento confirmado normal
               r_gmovi.reversado       := 'N';
               r_gmovi.cod_rubro       := v_cod_rubro;
               r_gmovi.tip_mov_rubro   := 'C';

                  pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
            end if;

            if pag_cta.FU_OBT_COD_ERROR() <> 0 then
                raise_application_error(-20000,
                                  'Error al desembolsar prestamo ' ||V_LUGAR||'-' ||sqlerrm );
            end if;
            --COMMIT;
           
      end if;

      p_nro_cta_generada:=  v_nro_cuenta;
      p_hora:= v_hora;

 EXCEPTION
     WHEN OTHERS THEN
        if sqlcode <= -20000 then
           raise;
        else
            raise_application_error(-20000,'Desembolso-'||v_lugar||' '||sqlerrm);
        end if;


end prp_des_atm_prestamo_res_04;
/

