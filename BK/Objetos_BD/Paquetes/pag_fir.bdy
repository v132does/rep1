CREATE OR REPLACE PACKAGE BODY IT.PAG_FIR IS
    procedure pr_dis_documento(p_cod_documento in number,
                               p_tip_documento in varchar2,
                               p_nro_secuencia in number,
                               p_cod_beneficiario in varchar2)
    is
        v_nro_secuencia  ge_fir_solicitudes.nro_secuencia%type;
        v_cod_firmante   ge_fir_solicitudes.cod_firmante%type;
        v_ind_beneficiario ge_fir_circuitos.ind_beneficiario%type;
    begin
      begin
        select s.nro_secuencia,s.cod_persona,s.ind_beneficiario
          into v_nro_secuencia,v_cod_firmante,v_ind_beneficiario
          from ge_fir_circuitos s
         where s.tip_documento = p_tip_documento
           and s.nro_secuencia = p_nro_secuencia + 1;
      exception
        when no_data_found then
           null;
        when others then
           raise_application_error(-20000,'Error al buscar el siguiente firmante.'||sqlerrm);
      end;

      if v_cod_firmante is null and nvl(v_ind_beneficiario,'N') = 'S' then
         v_cod_firmante := p_cod_beneficiario;
      end if;

      if v_cod_firmante is not null then
         insert into ge_fir_solicitudes(cod_documento,nro_secuencia,cod_firmante,estado)
                                 values(p_cod_documento,v_nro_secuencia,v_cod_firmante,'P');
      end if;
    end;

    procedure pr_obt_producto ( p_ind_producto varchar2,
                                p_cod_modulo out ba_modulos.cod_modulo%type,
                                p_cod_modalidad out ge_modalidades.cod_modalidad%type) is
    begin
      begin
        select cod_modulo, cod_modalidad
          into p_cod_modulo, p_cod_modalidad
          from ge_modalidades m, ba_cod_referencias r
         where r.dominio = 'TIP_PRODUCTOS'
           and r.val_minimo = p_ind_producto
           and m.cod_modulo||m.cod_modalidad = r.val_maximo;
      exception
        when others then
          p_cod_modulo := null;
          p_cod_modalidad := null;
      end;
    end;

    procedure pr_val_sol_fir_cta (p_cod_persona bw_sol_fir_cuentas.cod_persona%type,
                                  p_cod_modulo bw_sol_fir_cuentas.cod_modulo%type,
                                  p_cod_modalidad bw_sol_fir_cuentas.cod_modalidad%type,
                                  p_ind_correcto out varchar,
                                  p_cod_error out number,
                                  p_men_error out varchar) is
      v_can_firmas number;
      v_can_firmantes number;
      v_can_fir_con number;
      v_tip_persona ba_personas.tipo%type;
    begin
      p_ind_correcto := 'N';
      p_cod_error := v_cod_sin_error;
      begin
        select count(*), sum(decode(est_firmante, 'A', 1, 0)),
               sum(decode(relacion, 'Y', 1, 0))
          into v_can_firmas, v_can_firmantes, v_can_fir_con
          from bw_sol_fir_cuentas
         where cod_persona = p_cod_persona
           and cod_modulo = p_cod_modulo
           and cod_modalidad = p_cod_modalidad
           and est_cuenta = 'P';
      exception
        when others then
          v_can_firmas := 0;
          v_can_firmantes := 0;
      end;

      begin
        select tipo
          into v_tip_persona
          from ba_personas
         where cod_persona = p_cod_persona;
      exception
        when others then
          v_tip_persona := 'F';
      end;

      if nvl(v_can_firmas, 0) = nvl(v_can_firmantes, 0) then
         p_ind_correcto := 'S';
      else
         p_cod_error := 1027;
         p_men_error := 'Existen firmantes que debe confirmar el pedido.';
      end if;
      if nvl(v_can_fir_con, 0) = 1 and p_ind_correcto = 'S' and v_tip_persona = 'J' then
         p_cod_error := 1004;
         p_men_error := 'Deben existir mas de un firmante para la cuenta.';
      end if;

      if p_cod_error <> v_cod_sin_error then
        p_ind_correcto := 'N';
      end if;

    end;
    procedure pr_ins_sol_firmantes (p_ind_producto varchar2,
                                    p_cod_persona bw_sol_fir_cuentas.cod_persona%type,
                                    p_nro_cedula bw_sol_fir_cuentas.nro_cedula%type,
                                    p_nro_telefono bw_sol_fir_cuentas.nro_telefono%type,
                                    p_dir_correo bw_sol_fir_cuentas.dir_correo%type,
                                    p_tip_vinculo bw_sol_fir_cuentas.cod_tip_vinculo%type,
                                    p_relacion bw_sol_fir_cuentas.relacion%type,
                                    p_cod_per_fir out bw_sol_fir_cuentas.cod_per_fir%type,
                                    p_cod_error out number,
                                    p_men_error out varchar2) is
      v_exi_vinculo varchar2(1);
      v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
      v_fec_vencimiento ba_vinculos.fec_vencimiento%type;
      v_exi_sol_pen ba_vinculos.estado%type;
      v_cod_modulo ba_modulos.cod_modulo%type;
      v_cod_modalidad ge_modalidades.cod_modalidad%type;
      v_exi_firmante varchar2(1);
    begin
      Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 9; end;

      p_cod_error := v_cod_sin_error; -- sin errores

      pr_obt_producto(p_ind_producto, v_cod_modulo, v_cod_modalidad);

      begin
        select p.cod_persona
          into p_cod_per_fir
          from ba_personas p, ba_per_documentos d
         where p.nro_documento = p_nro_cedula
           and p.cod_persona = 'F'
           and p.tipo = 1
           and p.nro_documento = d.nro_documento;
      exception
        when others then
          begin
            select cod_persona
              into p_cod_per_fir
              from ba_personas
             where tipo = 'F'
               and nro_documento =  p_nro_cedula;
          exception
            when too_many_rows then
               p_cod_per_fir := null;
               p_cod_error := 1023;
               p_men_error := 'Existe mas de una persona con el mismo nro. de documento.';
            when no_data_Found then
               p_cod_per_fir := null;
            when others then
               p_cod_per_fir := null;
               p_cod_error := v_cod_err_sql;
               p_men_error := 'Error al buscar el firmante. '||sqlerrm;
         end;
       end;

       if p_cod_per_fir is not null then
         begin
           select distinct 'S'
             into v_exi_firmante
             from bw_sol_fir_cuentas s
            where cod_persona = p_cod_persona
              and cod_per_fir = p_cod_per_fir
              and cod_modulo = v_cod_modulo
              and cod_modalidad = v_cod_modalidad
              and est_firmante = 'P'
              and est_cuenta = 'P';
          exception
            when others then
              v_exi_firmante := 'N';
          end;
       else
         begin
           select distinct 'S'
             into v_exi_firmante
             from bw_sol_fir_cuentas s
            where cod_persona = p_cod_persona
              and nro_cedula = p_nro_cedula
              and cod_modulo = v_cod_modulo
              and cod_modalidad = v_cod_modalidad
              and est_firmante = 'P'
              and est_cuenta = 'P';
          exception
            when others then
              v_exi_firmante := 'N';
          end;
       end if;

       if nvl(v_exi_firmante, 'N') = 'S' then
          p_cod_error := 1040;
          p_men_error := 'El firmante ya fue ingresado.';
       end if;


       if p_cod_persona is not null and p_cod_persona = p_cod_per_fir and p_cod_error = v_cod_sin_error then
          p_cod_error := 1024;
          p_men_error := 'El cliente principal no puede agregarse como otro firmante.';
       end if;

       -- Validacion persona
       if p_cod_error = v_cod_sin_error and p_cod_per_fir is not null then
         null;
         --paa_pro.PR_VAL_PERSONAS(p_cod_per_fir, v_cod_modulo, v_cod_modalidad, p_cod_error, p_men_error);
       end if;

       if p_relacion not in ('Y', 'O', 'R') then
         p_cod_error := 1025;
         p_men_error := 'Relacion no valida.';
       end if;

       if p_relacion is null then
         p_cod_error := 1026;
         p_men_error := 'Debe ingresar la relacion.';
       end if;

       begin
         select distinct 'S'
           into v_exi_sol_pen
           from bw_sol_fir_cuentas
          where cod_modulo = v_cod_modulo
            and cod_modalidad = v_cod_modalidad
            and cod_persona = p_cod_persona
            and ((cod_per_fir is not null and cod_per_fir = p_cod_per_fir) or
                 (cod_per_fir is null and nro_cedula = p_nro_cedula))
            and est_firmante = 'P';
      exception
         when others then
           v_exi_sol_pen := 'N';
      end;

      if nvl(v_exi_sol_pen, 'N') = 'S' then
        p_cod_error := 1027;
        p_men_error := 'Solicitud de firmante pendiente de aprobacion.';
      end if;

       if p_cod_error = v_cod_sin_error then
         if p_cod_per_fir is not null then
           begin
             select distinct 'S', fec_vencimiento
               into v_exi_vinculo, v_fec_vencimiento
               from ba_vinculos v
              where v.cod_persona = p_cod_persona
                and v.cod_per_vinculo = p_cod_per_fir;
            exception
              when others then
                v_exi_vinculo := 'N';
            end;
          else
            v_exi_vinculo := 'N';
          end if;

          if nvl(v_exi_vinculo, 'N') = 'S' then
             if v_fec_vencimiento is not null and v_fec_vencimiento >= v_fec_actual then
                p_cod_error := 1028;
                p_men_error := 'El vinculo se encuentra vencido. Comuniquese con su gestor.';
             end if;
          else
             if p_tip_vinculo is not null then
              declare
                v_can_tip_vinculo number;
              begin
                select count(*)
                  into v_can_tip_vinculo
                  from ba_tip_vinculos v
                 where v.cod_tip_vinculo = p_tip_vinculo;

                if v_can_tip_vinculo = 0 then
                  p_cod_error := 1029;
                  p_men_error := 'Ingrese un tipo de vinculo valido';
                end if;
              end;
            else
              p_cod_error := 1029;
              p_men_error := 'Debe ingresar un tipo de vinculo.';
            end if;
          end if;
       end if;

       if p_cod_error = v_cod_sin_error then
         if p_nro_telefono is null then
            p_cod_error := 1030;
            p_men_error := 'Debe ingresar el numero de telefono.';
         end if;
         if p_dir_correo is null then
            p_cod_error := 1031;
            p_men_error := 'Debe ingresar la direccion de correo.';
         end if;
       end if;

       if p_cod_error = v_cod_sin_error then
         begin
           insert into BW_SOL_FIR_CUENTAS(cod_persona, cod_modulo, cod_modalidad,
                                          nro_cedula, nro_telefono, dir_correo,
                                          cod_tip_vinculo, relacion, est_firmante, est_cuenta, cod_per_fir, Fec_Habil)
           values(p_cod_persona, v_cod_modulo, v_cod_modalidad,
                  p_nro_cedula, p_nro_telefono, p_dir_correo,
                  p_tip_vinculo, p_relacion, 'P', 'P', p_cod_per_fir, v_fec_actual);
          exception
            when others then
              p_cod_error := v_cod_err_sql;
              p_men_error := 'Error al insertar la solciitud de Firmante. '||sqlerrm;
          end;
       else
           prg_ins_log_programas('PAG_FIR.PR_INS_SOL_FIRMANTES', substr('Firmante '||p_cod_per_fir||'. '||p_cod_error||' - '||p_men_error, 1, 4000),
                                  p_cod_persona, null);
       end if;
    end;

    procedure pr_act_est_sol_fir (p_ind_producto varchar2,
                                  p_cod_persona bw_sol_fir_cuentas.cod_persona%type,
                                  p_cod_per_fir bw_sol_fir_cuentas.cod_per_fir%type,
                                  p_nro_ced_fir bw_sol_fir_cuentas.nro_cedula%type,
                                  p_estado bw_sol_fir_cuentas.est_firmante%type,
                                  p_cod_error out number,
                                  p_men_error out varchar2) is
      v_exi_vinculo varchar2(1);
      v_exi_sol_cda varchar2(1);
      v_tip_vinculo bw_sol_fir_cuentas.cod_tip_vinculo%type;
      v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
      v_fec_vencimiento ba_vinculos.fec_vencimiento%type;
      v_est_solicitud bw_sol_fir_cuentas.est_firmante%type;
      v_referencia bw_sol_fir_cuentas.referencia%type;
      v_ind_cre_cuenta varchar2(1);
      v_cod_err_val_fir number;
      v_men_err_val_fir varchar2(4000);
      v_cod_modulo ba_modulos.cod_modulo%type;
      v_cod_modalidad ge_modalidades.cod_modalidad%type;
      v_cod_moneda ah_cta_vistas.cod_moneda%type;
      v_nro_cuenta ge_cuentas.nro_cuenta%type;
      v_nro_cta_alcancia ah_cta_vistas.nro_cuenta%type;
     -- v_nro_tar_debito ah_tar_debitos.nro_tarjeta%type;
      v_ind_fir_correcto varchar2(1);
      v_ind_doc_correcto varchar2(1);
    begin
      Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 9; end;

      p_cod_error := v_cod_sin_error; -- sin errores

      pr_obt_producto(p_ind_producto, v_cod_modulo, v_cod_modalidad);

      begin
         select est_firmante, referencia, cod_tip_vinculo
           into v_est_solicitud, v_referencia, v_tip_vinculo
           from bw_sol_fir_cuentas
          where cod_modulo = v_cod_modulo
            and cod_modalidad = v_cod_modalidad
            and cod_persona = p_cod_persona
            and ((cod_per_fir is not null and cod_per_fir = p_cod_per_fir) or
                 (cod_per_fir is null and nro_cedula = p_nro_ced_fir))
            and nro_cuenta is null
            and est_cuenta = 'P';
      exception
        when no_data_found then
          p_cod_error := 1022;
          p_men_error := 'No se encuentra la solicitud del firmante. Favor verifique.';
        when others then
          p_cod_error := v_cod_err_sql;
          p_men_error := 'Error al buscar al firmante. '||sqlerrm;
      end;
      if v_est_solicitud = 'A' then
          p_cod_error := 1032;
          p_men_error := 'La solicitud de firmante ya fue aprobada.';
      elsif v_est_solicitud = 'R' then
          p_cod_error := 1033;
          p_men_error := 'La solicitud de firmante ya fue rechazada.';
      elsif v_est_solicitud = 'C' then
          p_cod_error := 1034;
          p_men_error := 'La solicitud de firmante caduco.';
      end if;
      if p_estado = 'A' and p_cod_error = v_cod_sin_error then
        begin
          select distinct 'S', fec_vencimiento
            into v_exi_vinculo, v_fec_vencimiento
            from ba_vinculos v
           where v.cod_persona = p_cod_persona
             and v.cod_per_vinculo = p_cod_per_fir;
        exception
          when others then
            v_exi_vinculo := 'N';
        end;

        if nvl(v_exi_vinculo, 'N') = 'S' then
          if v_fec_vencimiento is not null and v_fec_vencimiento >= v_fec_actual then
             p_cod_error := 1028;
             p_men_error := 'El vinculo se encuentra vencido. Comuniquese con su gestor.';
          end if;
        else
          if p_cod_error = v_cod_sin_error then
            begin
              insert into ba_vinculos (cod_persona,cod_per_vinculo,tipo,estado)
              values (p_cod_persona, p_cod_per_fir, v_tip_vinculo, 'A');
            exception
              when others then
                p_cod_error := v_cod_err_sql;
                p_men_error := 'Error al insertar el codigo de Vinculo'||sqlerrm;
            end;
          end if;
        end if;
    end if;
    if nvl(p_estado, 'x') not in ('R','A') and p_cod_error = v_cod_sin_error then
       p_cod_error := 1035;
       p_men_error := 'Estado de Solicitud de Firmante no valido.';
    end if;
    if p_cod_error = v_cod_sin_error then
       begin
         update bw_sol_fir_cuentas
            set est_firmante = p_estado,
                cod_per_fir = nvl(cod_per_fir, p_cod_per_fir),
                fec_aprobacion = v_fec_actual
          where cod_modulo = v_cod_modulo
            and cod_modalidad = v_cod_modalidad
            and cod_persona = p_cod_persona
            and ((cod_per_fir is not null and cod_per_fir = p_cod_per_fir) or
                 (cod_per_fir is null and nro_cedula = p_nro_ced_fir))
            and est_firmante = 'P';
       exception
         when others then
           p_cod_error := v_cod_err_sql;
           p_men_error := 'Error al Actualizar el estado de la Solicitud de Firmante. '||sqlerrm;
       end;
       if p_estado = 'R' then
         begin
           update bw_sol_fir_cuentas
              set est_firmante = 'C',
                  fec_aprobacion = v_fec_actual
            where cod_modulo = v_cod_modulo
              and cod_modalidad = v_cod_modalidad
              and cod_persona = p_cod_persona
              and est_firmante = 'P';
         exception
           when others then
             p_cod_error := v_cod_err_sql;
             p_men_error := 'Error al Actualizar el estado Firmante. '||sqlerrm;
         end;
         begin
           update bw_sol_fir_cuentas
              set est_cuenta = 'C',
                  observacion = 'Cancelado por el firmante '||p_cod_per_fir
            where cod_modulo = v_cod_modulo
              and cod_modalidad = v_cod_modalidad
              and cod_persona = p_cod_persona
              and est_cuenta = 'P';
         exception
           when others then
             p_cod_error := v_cod_err_sql;
             p_men_error := 'Error al Actualizar Cancelar la Solicitud. '||sqlerrm;
         end;

         if v_cod_modulo = 3 and v_cod_modalidad in (33,37) then -- CDA --Plazo Fijo
           update ah_sol_certificados
              set estado = 'C'
            where nro_solicitud = v_referencia;
         end if;
       end if;
    end if;

    if p_estado = 'A' and p_cod_error = v_cod_sin_error then
     if v_cod_modulo = 3 and v_cod_modalidad in (33,37) then -- CDA --Plazo Fijo
         begin
           select distinct 'S'
             into v_exi_sol_cda
             from ah_sol_certificados
            where cod_persona = p_cod_persona
              and estado = 'P'
              and cod_modalidad in (33,37);
         exception
           when others then
              v_exi_sol_cda := 'N';
         end;
         if nvl(v_exi_sol_cda, 'N') = 'S' then
           pr_val_sol_fir_cta (p_cod_persona, v_cod_modulo, v_cod_modalidad,
                               v_ind_cre_cuenta, v_cod_err_val_fir, v_men_err_val_fir);
           if v_ind_cre_cuenta = 'S' then
             --paa_pro.PR_CRE_CTA_CDA (v_referencia, p_cod_error, p_men_error);
             null;
           end if;
         else
           p_cod_error := 1022;
           p_men_error := 'Error al buscar la solicitud del Firmante.';
         end if;

      elsif v_cod_modulo = 3 and v_cod_modalidad = 31 then --AHORRO
         begin
           select cod_moneda
             into v_cod_moneda
             from ba_monedas m
            where m.cod_mon_bco_central = v_referencia;
         exception
           when others then
             p_cod_error := v_cod_err_sql;
             p_men_error := 'Error al buscar la moneda. '||sqlerrm;
         end;
         if p_cod_error = v_cod_sin_error then
           --pr_val_sol_fir_cta (p_cod_persona, v_cod_modulo, v_cod_modalidad,
           --                    v_ind_cre_cuenta, v_cod_err_val_fir, v_men_err_val_fir);
           pr_val_sol_cta(p_cod_persona, v_cod_modulo, v_cod_modalidad, v_ind_fir_correcto, v_ind_doc_correcto);
           if v_ind_fir_correcto = 'S' and v_ind_doc_correcto = 'S' then
             /* PAA_PRO.PR_CRE_CTA_AHORRO(p_cod_persona, v_cod_moneda, 'C', -- O: Onbording, -- C: Convencional
                                        p_cod_error, p_men_error,
                                        v_nro_cuenta, v_nro_cta_alcancia, v_nro_tar_debito);*/
          null;
          end if;
         end if;
      elsif v_cod_modulo = 4 and v_cod_modalidad = 41 then --AHORRO
         begin
           select cod_moneda
             into v_cod_moneda
             from ba_monedas m
            where m.cod_mon_bco_central = v_referencia;
         exception
           when others then
             p_cod_error := v_cod_err_sql;
             p_men_error := 'Error al buscar la moneda. '||sqlerrm;
         end;
         if p_cod_error = v_cod_sin_error then
           pr_val_sol_fir_cta (p_cod_persona, v_cod_modulo, v_cod_modalidad,
                               v_ind_cre_cuenta, v_cod_err_val_fir, v_men_err_val_fir);
           if v_ind_cre_cuenta = 'S' then
             null;
              --PAC_PRO.PR_SOL_CTA_CORRIENTES(p_cod_persona, v_cod_moneda, p_cod_error, p_men_error, v_nro_cuenta);
           end if;
         end if;
      end if;
      if p_cod_error = v_pro_cor_pen then
         p_cod_error := v_cod_sin_error;
      end if;
    end if;
    if p_cod_error <> v_cod_sin_error then
       prg_ins_log_programas('PAG_FIR.PR_ACT_EST_SOL_FIR', substr('Firmante '||p_cod_per_fir||'. '||p_cod_error||' - '||p_men_error, 1, 4000),
                              p_cod_persona, null);
       rollback;
    end if;
  end;

  procedure pr_can_est_sol_fir is
    v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_can_dia_can_fir number := NVL(fug_obt_pardinamico('DIA_ESP_CAN_PEN'), 30);
    cursor c_fir is
    select f.cod_modulo, f.cod_modalidad, f.cod_persona, nvl(f.cod_per_fir, 'x') cod_per_fir,
           f.referencia
      from bw_sol_fir_cuentas f
     where est_firmante = 'P'
       and fec_habil + v_can_dia_can_fir <= v_fec_actual;
  begin
    for c in c_fir loop
      begin
        update bw_sol_fir_cuentas
           set est_firmante = 'C',
               est_cuenta = 'C',
               fec_aprobacion = v_fec_actual
         where cod_modulo = c.cod_modulo
           and cod_modalidad = c.cod_modalidad
           and cod_persona = c.cod_persona
           and est_firmante = 'P';
      exception
        when others then
           RAISE_APPLICATION_ERROR(-20000,'Error al Actuaizar el estado de la Solicitud de Firmante. '||sqlerrm);
      end;
      begin
        update bw_sol_fir_cuentas
           set est_cuenta = 'C'
         where cod_modulo = c.cod_modulo
           and cod_modalidad = c.cod_modalidad
           and cod_persona = c.cod_persona
           and est_cuenta = 'P';
      exception
        when others then
           RAISE_APPLICATION_ERROR(-20000,'Error al Actuaizar el estado de la Solicitud de Firmante. '||sqlerrm);
      end;

      if c.cod_modulo = 3 and c.cod_modalidad in (33,37) then -- CDA --Plazo Fijo
         update ah_sol_certificados
            set estado = 'C'
          where nro_solicitud = c.referencia
            and estado = 'P';
      end if;
    end loop;
  end;
  procedure pr_env_arc_fir_pen is
  cursor c_fir_pen is
  select c.cod_persona, p.nom_completo tit_cuenta, c.cod_modulo, c.cod_modalidad, m.descripcion des_modalidad,
         c.nro_cedula, c.nro_telefono, c.dir_correo,
         c.cod_tip_vinculo, t.descripcion vinculo, c.relacion cod_relacion, r.significado relacion,
         c.cod_per_fir, f.nom_completo nom_firmante, c.fec_habil
    from bw_sol_fir_cuentas c, ba_personas p, ba_personas f, ba_tip_vinculos t, ba_cod_referencias r,
         ge_modalidades m
   where c.est_firmante = 'P'
     and c.cod_persona = p.cod_persona
     and c.cod_per_fir = f.cod_persona(+)
     and c.cod_tip_vinculo = t.cod_tip_vinculo
     and r.dominio = 'RELACION'
     and r.val_minimo = c.relacion
     and c.cod_modulo = m.cod_modulo
     and c.cod_modalidad = m.cod_modalidad
   order by c.fec_habil, c.cod_persona, c.cod_per_fir;
   v_dir_correo ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('NOT_MAI_OPE_FIR_PEN');
   v_ind_env_mail varchar2(1) := nvl(fug_obt_pardinamico('AHO_IND_ENV_NOT_MAI'), 'N');
   v_nom_archivo varchar2(500);
   v_registro CLOB;
   conn utl_smtp.connection;
   v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
   BEGIN
    if nvl(v_ind_env_mail, 'N') = 'S' then
      begin
        v_nom_archivo := 'SOL_FIR_PEN.CSV';
        conn := it_mail.begin_mail( fug_obt_dir_correo,
                                    v_dir_correo,
                                    'Solicitudes de Firmantes de Cuentas Pendientes',
                                    IT_MAIL.MULTIPART_MIME_TYPE);

        it_mail.attach_text(conn, 'Se informa el listado de firmantes pendientes de aprobacion de la fecha '||to_char(v_fec_actual,'DD/MM/YYYY')||'.'||chr(10)||chr(10)||
                                  'Atentamente' || chr(10),
                                  'text/plain');
        v_registro := 'FEC. HABIL SOL.'||'COD. CLIENTE'|| ';' ||'NOMBRE'|| ';' ||'COD. MODULO'|| ';' ||'COD. MODALIDAD'|| ';' ||'PRODUCTO'|| ';' ||
                      'COD. CLIENTE FIRMANTE'|| ';' ||'NOMBRE FIRMANTE'|| ';' ||'NRO. CEDULA'|| ';'||
                      'NRO. TELEFONO'|| ';' ||'CORREO'|| ';' ||'VINCULO'|| ';' ||
                      'RELACION'|| chr(10);

        for c in c_fir_pen loop
          v_registro := v_registro|| c.fec_habil|| ';' ||
                        c.cod_persona|| ';' ||
                        c.tit_cuenta|| ';' ||
                        c.cod_modulo|| ';' ||
                        c.cod_modalidad|| ';' ||
                        c.des_modalidad|| ';' ||
                        c.cod_per_fir|| ';' ||
                        c.nom_firmante|| ';' ||
                        c.nro_cedula|| ';' ||
                        c.nro_telefono|| ';' ||
                        c.dir_correo|| ';' ||
                        c.vinculo|| ';' ||
                        c.relacion|| chr(10);
         end loop;

        it_mail.begin_attachment( conn,'text/plain',false, v_nom_archivo );
        it_mail.write_text( conn, v_registro );
        it_mail.end_mail( conn );
      EXCEPTION
        when utl_smtp.transient_error or
             utl_smtp.permanent_error
        then
           begin
              utl_smtp.quit(conn);
           exception
              when utl_smtp.transient_error or
                   utl_smtp.permanent_error
              then
                 null;
           end;
        when others then
           begin
              utl_smtp.quit(conn);
           exception
              when utl_smtp.transient_error or
                   utl_smtp.permanent_error
              then
                 null;
           END;
       END;
     end if;
   END;

   PROCEDURE pr_ins_fir_cuentas (P_NRO_CUENTA GE_CTA_CLIENTES.NRO_CUENTA%TYPE,
                                 P_DIG_VERIFICADOR GE_CTA_CLIENTES.DIG_VERIFICADOR%TYPE,
                                 P_COD_OFICINA GE_CTA_CLIENTES.COD_OFICINA%TYPE,
                                 P_COD_PERSONA GE_CTA_CLIENTES.COD_PERSONA%TYPE,
                                 P_COD_MODULO GE_CTA_CLIENTES.COD_MODULO%TYPE,
                                 P_COD_MODALIDAD GE_CTA_CLIENTES.COD_MODALIDAD%TYPE,
                                 P_TIE_SOL_FIRMANTES VARCHAR2,
                                 P_COD_ERROR OUT NUMBER,
                                 P_MEN_ERROR OUT VARCHAR2) IS
     cursor c_firmantes is
     select c.cod_per_fir, c.relacion, referencia
       from bw_sol_fir_cuentas C
      where cod_persona = p_cod_persona
        and cod_modulo = p_cod_modulo
        and cod_modalidad = p_cod_modalidad
        and est_firmante = 'A'
        and est_cuenta = 'P';
   BEGIN
     begin
        begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := 1; end;
       p_cod_error := v_cod_sin_error;
       insert into ge_cta_clientes (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo,
                                    cod_modalidad, relacion)
       values (p_cod_persona, p_nro_cuenta, P_DIG_VERIFICADOR, p_cod_oficina, p_cod_modulo, p_cod_modalidad, 'P');
     exception
       when others then
         P_COD_ERROR := v_cod_err_sql;
         P_MEN_ERROR := 'Error al insertar el firmante principal. '||sqlerrm;
     end;
     if nvl(p_tie_sol_firmantes, 'N') = 'S' then
       for c in c_firmantes loop
         BEGIN
           begin
             p_cod_error := v_cod_sin_error;
             insert into ge_cta_clientes (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo,
                                          cod_modalidad, relacion)
             values (c.cod_per_fir, p_nro_cuenta, P_DIG_VERIFICADOR, p_cod_oficina, p_cod_modulo, p_cod_modalidad, c.relacion);
           exception
             when others then
               P_COD_ERROR := v_cod_err_sql;
               P_MEN_ERROR := 'Error al insertar el firmante. '||sqlerrm;
           end;
           begin
             update bw_sol_fir_cuentas
                set est_cuenta = 'A',
                    nro_cuenta = p_nro_cuenta
              where referencia = c.referencia
                and cod_modulo = p_cod_modulo
                and cod_modalidad = p_cod_modalidad
                and cod_persona = p_cod_persona
                and est_cuenta = 'P';
           exception
             when others then
               P_COD_ERROR := v_cod_err_sql;
               P_MEN_ERROR := 'Error al actualizar el estado de la solicitud del firmante. '||sqlerrm;
           end;
         END;
       end loop;
     end if;
     if p_cod_error <> v_cod_sin_error then
       prg_ins_log_programas('PAG_FIR.PR_INS_FIR_CUENTAS', substr(p_cod_error||' - '||p_men_error, 1, 4000),
                              p_cod_persona, p_nro_cuenta);
       rollback;
     end if;
   END;
   procedure pr_gen_ext_req(p_cod_persona ba_personas.cod_persona%type,
                            p_nro_cuenta ge_cuentas.nro_cuenta%type,
                            p_cod_error out number,
                            p_men_error out varchar2) is
   begin
     prg_gen_extracto_tmp(p_cod_persona, p_nro_cuenta);
   exception
     when others then

       p_cod_error := v_cod_err_sql;
       p_men_error := 'Error al generar datos del estracto. '||sqlerrm;
       prg_ins_log_programas('PAG_FIR.PR_GEN_EXT_REQ', substr(p_men_error, 1, 4000),
                              p_cod_persona, p_nro_cuenta);
   end;
   procedure pr_act_tip_extracto(p_cod_persona  in ge_clientes.cod_persona%type,
                                  p_tip_extracto in ge_clientes.tip_extracto%type,
                                  p_cod_error    out number,
                                  p_men_error    out varchar2) is
    v_existe varchar2(1):='N';
   begin
     p_cod_error := 0;

     begin
       select 'S'
         into v_existe
         from ba_cod_referencias a
        where a.dominio = 'TIP_IMPRESION'
          and a.val_minimo = p_tip_extracto;
     exception
       when no_data_found then
         p_cod_error := 999;
         p_men_error := 'Valor incorrecto para el dominio TIP_IMPRESION. Requerido: ' ||
                        p_tip_extracto;
         prg_ins_log_programas('PAG_FIR.PR_ACT_TIP_EXTRACTO',
                               substr(p_men_error, 1, 4000));

       when others then
         p_cod_error := 999;
         p_men_error := 'Error al validar el dominio TIP_IMPRESION. Requerido: ' ||
                        p_tip_extracto;
         prg_ins_log_programas('PAG_FIR.PR_ACT_TIP_EXTRACTO',
                               substr(p_men_error, 1, 4000));

     end;
     if p_cod_error = 0 and v_existe = 'S' then
       update ge_clientes
          set tip_extracto = p_tip_extracto
        where cod_persona = p_cod_persona;
     end if;
   exception
     when others then
       p_cod_error := 999;
       p_men_error := 'Error al actualizar GE_CLIENTES.TIP_EXTRACTO' || sqlerrm;
       prg_ins_log_programas('PAG_FIR.PR_ACT_TIP_EXTRACTO',
                             substr(p_men_error, 1, 4000));
   end;

   procedure pr_val_sol_cta(p_cod_persona ge_cta_clientes.cod_persona%type,
                            p_cod_modulo ge_cta_clientes.cod_modulo%type,
                            p_cod_modalidad ge_cta_clientes.cod_modalidad%type,
                            p_ind_fir_correcto out varchar,
                            p_ind_doc_correcto out varchar) is

     v_cod_error        number;
     v_men_error        varchar2(100);
     v_cant_doc         number;
   BEGIN

     p_ind_fir_correcto := 'N';
     p_ind_doc_correcto := 'N';
     v_cant_doc         := 0;

     pr_val_sol_fir_cta(p_cod_persona, p_cod_modulo, p_cod_modalidad, p_ind_fir_correcto, v_cod_error, v_men_error);

     begin
       select count(*)
         into v_cant_doc
         from BA_PER_IMA_DOCUMENTOS a
         where a.est_doc = 'N'
         and a.cod_persona = p_cod_persona;
     exception
       when others then
         v_cant_doc := 0;
     end;

     if v_cant_doc >= 1 then
       p_ind_doc_correcto := 'N';
     else
       p_ind_doc_correcto := 'S';
     end if;

   END;

   procedure pr_can_est_sol_pen is
      v_fec_actual     ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
      v_can_dia_pen    number := NVL(fug_obt_pardinamico('DIA_ESP_CAN_PEN'), 30);
      v_cod_cir_ahorro number := FUG_OBT_PARDINAMICO('COD_CIR_SOL_AHO');

     /* cursor c_sol is
        select a.nro_solicitud
          from ah_sol_cta_ahorro a
         where a.est_solicitud = 'P'
           and a.fecha + v_can_dia_pen <= v_fec_actual;*/

      cursor w_wf is
        select wf.cod_circuito, wf.referencia
          from wf_circuitos wf
         where wf.cod_tip_circuito = v_cod_cir_ahorro
           and trunc(wf.fec_inicio) + v_can_dia_pen <= v_fec_actual;
    begin
     /* for c in c_sol loop
        begin
          update ah_sol_cta_ahorro a
             set a.est_solicitud = 'C'
           where a.nro_solicitud = c.nro_solicitud;
        exception
          when others then
            RAISE_APPLICATION_ERROR(-20000,'Error al Actuaizar el estado de la solicitud de ahorro. '||sqlerrm);
        end;

      end loop;*/

      for w in w_wf loop
       /* begin
          paw_cir.pr_not_can_rec(15,w.referencia,w.cod_circuito,'Cancelado por estar pendiente mas de '||v_can_dia_pen||' dias.','S','R');
        exception
          when others then
            RAISE_APPLICATION_ERROR(-20000,'Error al cancelar circuito de workflow de solicitud de ahorro. '||sqlerrm);
        end;*/
        null;
      end loop;
    end;

    PROCEDURE pr_aso_cant_firmas(p_cod_persona in ba_personas.cod_persona%TYPE,
                               p_cant_firmas in bw_rol_permisos.can_firmas%TYPE,
                               p_cod_error   out number,
                               p_mensaje     out varchar2) IS

    v_log_mensaje varchar2(4000);
    v_existe      varchar2(1);
    v_exis_cant   number(2);
    v_cant        number(2);

  BEGIN

    BEGIN
      PRE_INI_APLICACION;
      PAE_CNF.G_COD_MODULO := 1;
    END;

    if p_cod_persona is null then
      p_mensaje   := 'La persona no puede ser nula.';
      p_cod_error := 2;
      return;
    end if;

    BEGIN
      Select 'S', count(*)
        into v_existe, v_exis_cant
        from bw_rol_permisos t
       where t.cod_persona = p_cod_persona
         and t.cod_tip_mensaje in
             (Select a.val_maximo
                from ba_cod_referencias a
               where a.dominio = 'ONB_EMP_OPERACIONES');
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        BEGIN
          insert into bw_rol_permisos
            (COD_PERSONA,
             COD_TIP_MENSAJE,
             COD_PERFIL,
             CONSULTA,
             INGRESA,
             AUTORIZA,
             CAN_FIRMAS)
            Select p_cod_persona,
                   a.val_maximo,
                   'REGISTRA',
                   'S',--consulta
                   'S',--ingresa
                   'N',--autoriza
                   p_cant_firmas cantidad_firmas
              from ba_cod_referencias a
             where a.dominio = 'ONB_EMP_OPERACIONES';
        EXCEPTION
          WHEN OTHERS THEN
            p_cod_error   := 6;
            p_mensaje     := 'Error al insertar Roles ';
            v_log_mensaje := substr('Error al insertar Roles ' ||
                                    DBMS_UTILITY.format_error_stack ||
                                    ' - ' ||
                                    DBMS_UTILITY.format_error_backtrace,
                                    1,
                                    4000);
            prg_ins_log_programas('PAG_FIR.PR_ASO_CANT_FIRMAS',
                                  v_log_mensaje,
                                  null,
                                  null);

        END;
      WHEN OTHERS THEN
        p_cod_error   := 6;
        p_mensaje     := 'Error al buscar Persona ' || p_cod_persona;
        v_log_mensaje := substr('Error al buscar Persona ' || p_cod_persona || ' ' ||
                                DBMS_UTILITY.format_error_stack || ' - ' ||
                                DBMS_UTILITY.format_error_backtrace,
                                1,
                                4000);
        prg_ins_log_programas('PAG_FIR.PR_ASO_CANT_FIRMAS',
                              v_log_mensaje,
                              p_cod_persona,
                              null);

    END;

    if v_existe = 'S' then
      begin
        Select count(*)
          into v_cant
          from ba_cod_referencias a
         where a.dominio = 'ONB_EMP_OPERACIONES';
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_cant := 0;
        WHEN OTHERS THEN
          p_cod_error   := 6;
          p_mensaje     := 'Error al Buscar cantidad de referencias ';
          v_log_mensaje := substr('Error al Buscar cantidad de referencias ' ||
                                  DBMS_UTILITY.format_error_stack || ' - ' ||
                                  DBMS_UTILITY.format_error_backtrace,
                                  1,
                                  4000);
          prg_ins_log_programas('PAG_FIR.PR_ASO_CANT_FIRMAS',
                                v_log_mensaje,
                                null,
                                null);

      END;
      if v_exis_cant < v_cant then
        update bw_rol_permisos t
           set t.can_firmas = p_cant_firmas
         where t.cod_persona = p_cod_persona;
        BEGIN
          insert into bw_rol_permisos
            (COD_PERSONA,
             COD_TIP_MENSAJE,
             COD_PERFIL,
             CONSULTA,
             INGRESA,
             AUTORIZA,
             CAN_FIRMAS)
            Select p_cod_persona,
                   a.val_maximo,                   
                   'REGISTRA',
                   'S',--consulta
                   'S',--ingresa
                   'N',--autoriza
                   p_cant_firmas cantidad_firmas
              from ba_cod_referencias a
             where a.dominio = 'ONB_EMP_OPERACIONES'
               and a.val_maximo not in
                   (Select t.cod_tip_mensaje
                      from bw_rol_permisos t
                     where t.cod_persona = p_cod_persona
                       and t.cod_tip_mensaje in
                           (Select a.val_maximo
                              from ba_cod_referencias a
                             where a.dominio = 'ONB_EMP_OPERACIONES'));
        EXCEPTION
          WHEN OTHERS THEN
            p_cod_error   := 6;
            p_mensaje     := 'Error al insertar Roles ';
            v_log_mensaje := substr('Error al insertar Roles ' ||
                                    DBMS_UTILITY.format_error_stack ||
                                    ' - ' ||
                                    DBMS_UTILITY.format_error_backtrace,
                                    1,
                                    4000);
            prg_ins_log_programas('PAG_FIR.PR_ASO_CANT_FIRMAS',
                                  v_log_mensaje,
                                  p_cod_persona,
                                  null);

        END;
      end if;
    end if;

    if nvl(p_cod_error, 0) = 0 then
      p_cod_error := 0;
      p_mensaje   := null;
    else
      prg_ins_log_programas('PAG_FIR.PR_ASO_CANT_FIRMAS',
                            substr(v_log_mensaje, 1, 4000),
                            null,
                            null);
    end if;

  EXCEPTION
    WHEN OTHERS THEN
      v_log_mensaje := substr(DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
      p_cod_error   := 99;
      p_mensaje     := 'Ocurrio un error inesperado durante el proceso';
      prg_ins_log_programas('PAG_FIR.PR_ASO_CANT_FIRMAS',
                            substr(v_log_mensaje, 1, 4000),
                            null,
                            null);
  END;

    PROCEDURE pr_aso_firmas(p_nro_cuenta  in ah_cta_vistas.nro_cuenta%TYPE,
                            p_cod_persona in ba_personas.cod_persona%TYPE,
                            p_cod_error   out number,
                            p_mensaje     out varchar2) IS

      v_log_mensaje     varchar2(4000);
      v_existe_c        varchar2(1);
      v_existe_p        varchar2(1);
      v_existe_r        varchar2(1);
      v_dig_verificador ah_cta_vistas.dig_verificador%TYPE;
      v_cod_oficina     ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modulo      ah_cta_vistas.cod_modulo%TYPE;
      v_cod_modalidad   ah_cta_vistas.cod_modalidad%TYPE;
      v_relacion        varchar2(1);
      v_naturaleza      ba_per_juridicas.naturaleza%TYPE;
      v_existe_jur      varchar2(1);
      v_ruc             ba_personas.nro_documento%TYPE;
      v_unipersonal     ba_per_juridicas.naturaleza%TYPE;
      v_documento       ba_personas.nro_documento%TYPE;
      v_existe_j        varchar2(1);
      v_existe_f        varchar2(1);
      v_relacion_j      varchar2(1);
      v_relacion_f      varchar2(1);
      v_cod_persona_f   ba_personas.cod_persona%TYPE;
      v_existe_cf        varchar2(1);
      v_existe_cj         varchar2(1);

    BEGIN
      BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;

      if p_nro_cuenta is null then
        p_mensaje   := 'La cuenta no puede ser nula.';
        p_cod_error := 1;
        return;
      end if;

      if p_cod_persona is null then
        p_mensaje   := 'La persona no puede ser nula.';
        p_cod_error := 2;
        return;
      end if;
      
      -- Verifico si ya es cliente   
      BEGIN
        Select 'S', t.nro_documento
          into v_existe_jur, v_ruc
          from ba_personas t
         where t.cod_persona = p_cod_persona;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_existe_jur := 'N';
        WHEN OTHERS THEN
          p_cod_error   := 5;
          p_mensaje     := 'Error al buscar Cliente ' || p_cod_persona;
          v_log_mensaje := substr('Error al buscar Cliente ' || p_cod_persona || ' ' ||
                           DBMS_UTILITY.format_error_stack || ' - ' ||
                           DBMS_UTILITY.format_error_backtrace, 1, 4000);
          prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, p_cod_persona, null);

      END;
      
      -- Verifico si pertenece a la sociedad unipersonal
      IF nvl(v_existe_jur,'N') ='S' THEN           
        BEGIN
          select j.naturaleza
            into v_unipersonal
            from  ba_per_juridicas j
           where j.cod_persona = p_cod_persona;            
        EXCEPTION
          when no_data_found then
            v_unipersonal := 'X';
          when others then
            v_unipersonal := 'X';
        END;
     END IF;
     
     -- Control para sociedad Unipersonal
     IF nvl(v_unipersonal, 'X') = fug_obt_pardinamico('VAL_MIN_EMP_UNI') then
          --Extraemos el documento a partir del RUC 
          BEGIN
            SELECT SUBSTR(bb.nro_documento,1,INSTR(bb.nro_documento, '-') - 1)
              INTO v_documento
              FROM ba_personas bb
             WHERE INSTR(bb.nro_documento, '-') > 0
               AND bb.nro_documento = v_ruc;
          EXCEPTION
            when no_data_found then
              v_documento := 'N';
            when others then
              v_documento := 'N';
          END;          
                
          IF nvl(v_documento,'N')!='N' THEN
             --Busco codigo de persona fisico 
             BEGIN     
               SELECT bb.cod_persona 
                 INTO v_cod_persona_f
                 FROM ba_personas bb
                WHERE bb.nro_documento = v_documento;
              EXCEPTION
              when no_data_found then
                v_cod_persona_f := 'N';
              when others then
                v_cod_persona_f := 'N';
            END;
          END IF;        
                  
        BEGIN
        Select 'S',
               dig_verificador,
               cod_oficina,
               cod_modulo,
               cod_modalidad,
               'Y'
          into v_existe_c,
               v_dig_verificador,
               v_cod_oficina,
               v_cod_modulo,
               v_cod_modalidad,
               v_relacion
          from ah_cta_vistas t
         where trim(t.nro_cuenta) = trim(p_nro_cuenta);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_existe_c := 'N';
        WHEN OTHERS THEN
          p_cod_error   := 3;
          p_mensaje     := 'Error al buscar Cuenta ' || p_nro_cuenta;
          v_log_mensaje := substr('Error al buscar Cuenta ' || p_nro_cuenta || ' ' ||
                           DBMS_UTILITY.format_error_stack || ' - ' ||
                           DBMS_UTILITY.format_error_backtrace, 1, 4000);
          prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, p_cod_persona, null);

      END;

      if nvl(v_existe_c, 'N') = 'N' then
        p_cod_error := 4;
        p_mensaje   := 'No se encontró la cuenta ';
        return;
      end if;
      
     --- Inicia flujo persona fisica
      BEGIN
        Select 'S'
          into v_existe_f
          from ba_personas t
         where t.cod_persona = v_cod_persona_f;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_existe_f := 'N';
        WHEN OTHERS THEN
          p_cod_error   := 5;
          p_mensaje     := 'Error al buscar Persona Fisica ' || v_cod_persona_f;
          v_log_mensaje := substr('Error al buscar Persona Fisica ' || v_cod_persona_f || ' ' ||
                           DBMS_UTILITY.format_error_stack || ' - ' ||
                           DBMS_UTILITY.format_error_backtrace, 1, 4000);
          prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, v_cod_persona_f, null);

      END;

      if nvl(v_existe_f, 'N') = 'N' then
        p_cod_error := 6;
        p_mensaje   := 'No se encontró la persona fisica ';
        return;
      end if;

      if nvl(v_existe_c, 'N') = 'S' and nvl(v_existe_f, 'N') = 'S' then
        BEGIN
          Select 'S', t.relacion
            into v_existe_cf, v_relacion_f
            from GE_CTA_CLIENTES t
           where t.nro_cuenta = p_nro_cuenta
             and trim(t.cod_persona) = trim(v_cod_persona_f);
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_existe_cf := 'N';
            v_relacion_f:= 'N';
          WHEN OTHERS THEN
            p_cod_error   := 7;
            p_mensaje     := 'Error al buscar relacion cuenta-fisica ' || v_cod_persona_f;
            v_log_mensaje := substr('Error al buscar relacion cuenta-fisica ' || v_cod_persona_f || ' ' ||
                             DBMS_UTILITY.format_error_stack || ' - ' ||
                             DBMS_UTILITY.format_error_backtrace, 1, 4000);
            prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, v_cod_persona_f, null);

        END;
     
        IF nvl(v_existe_cf, 'N') = 'N' and nvl(v_relacion_f, 'N')='N' then
          BEGIN
            insert into GE_CTA_CLIENTES
              (COD_PERSONA,
               NRO_CUENTA,
               DIG_VERIFICADOR,
               COD_OFICINA,
               COD_MODULO,
               COD_MODALIDAD,
               RELACION,
               EST_RELACION)
            values
              (v_cod_persona_f,
               p_nro_cuenta,
               v_dig_verificador,
               v_cod_oficina,
               v_cod_modulo,
               v_cod_modalidad,
               'P', --Principal
               'A');
          EXCEPTION
            WHEN OTHERS THEN
              p_cod_error   := 9;
              p_mensaje     := 'Error al insertar Cuenta Cliente fisico ';
              v_log_mensaje := substr('Error al insertar Cuenta Cliente fisico ' ||
                               DBMS_UTILITY.format_error_stack || ' - ' ||
                               DBMS_UTILITY.format_error_backtrace, 1, 4000);
              prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, null, null);

              END;
          END IF;
        end if;    

      -- Inicia flujo persona juridica
      BEGIN
        Select 'S'
          into v_existe_j
          from ba_personas t
         where t.cod_persona = p_cod_persona;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_existe_j := 'N';
        WHEN OTHERS THEN
          p_cod_error   := 5;
          p_mensaje     := 'Error al buscar Persona Juridica ' || p_cod_persona;
          v_log_mensaje := substr('Error al buscar Persona Juridica ' || p_cod_persona|| ' ' ||
                           DBMS_UTILITY.format_error_stack || ' - ' ||
                           DBMS_UTILITY.format_error_backtrace, 1, 4000);
          prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, p_cod_persona, null);

      END;

      if nvl(v_existe_j, 'N') = 'N' then
        p_cod_error := 6;
        p_mensaje   := 'No se encontró la persona juridica ';
        return;
      end if;

      if nvl(v_existe_j, 'N') = 'S' and nvl(v_existe_c, 'N') = 'S' then
        BEGIN
          Select 'S', t.relacion
            into v_existe_cj, v_relacion_j
            from GE_CTA_CLIENTES t
           where t.nro_cuenta = p_nro_cuenta
             and t.cod_persona = p_cod_persona;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_existe_cj := 'N';
            v_relacion_j:= 'N';
          WHEN OTHERS THEN
            p_cod_error   := 7;
            p_mensaje     := 'Error al buscar relacion persona Juridica ' || p_cod_persona;
            v_log_mensaje := substr('Error al relacion persona Juridica ' || p_cod_persona || ' ' ||
                             DBMS_UTILITY.format_error_stack || ' - ' ||
                             DBMS_UTILITY.format_error_backtrace, 1, 4000);
            prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, p_cod_persona, null);

        END;
       
        IF nvl(v_existe_cj,'N')='N' and nvl(v_relacion_j,'N')='N' then  
          BEGIN
            insert into GE_CTA_CLIENTES
              (COD_PERSONA,
               NRO_CUENTA,
               DIG_VERIFICADOR,
               COD_OFICINA,
               COD_MODULO,
               COD_MODALIDAD,
               RELACION,
               EST_RELACION)
            values
              (p_cod_persona,
               p_nro_cuenta,
               v_dig_verificador,
               v_cod_oficina,
               v_cod_modulo,
               v_cod_modalidad,
               'O', --Indistinta
               'A');
          EXCEPTION
            WHEN OTHERS THEN
              p_cod_error   := 9;
              p_mensaje     := 'Error al insertar Cuenta Cliente Juridica ';
              v_log_mensaje := substr('Error al insertar Cuenta Cliente Juridica ' ||
                               DBMS_UTILITY.format_error_stack || ' - ' ||
                               DBMS_UTILITY.format_error_backtrace, 1, 4000);
              prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, null, null);
          END;          
          END IF;          
        end if;      

        if nvl(p_cod_error, 0) = 0 then
          p_cod_error := 0;
          p_mensaje   := null;
        else
          prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', substr(v_log_mensaje, 1, 4000), null, null);
        end if;  
              
     ELSE
            
      -- Todas las sociedades        
      BEGIN
        Select 'S',
               dig_verificador,
               cod_oficina,
               cod_modulo,
               cod_modalidad,
               'Y'
          into v_existe_c,
               v_dig_verificador,
               v_cod_oficina,
               v_cod_modulo,
               v_cod_modalidad,
               v_relacion
          from ah_cta_vistas t
         where t.nro_cuenta = p_nro_cuenta;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_existe_c := 'N';
        WHEN OTHERS THEN
          p_cod_error   := 3;
          p_mensaje     := 'Error al buscar Cuenta ' || p_nro_cuenta;
          v_log_mensaje := substr('Error al buscar Cuenta ' || p_nro_cuenta || ' ' ||
                           DBMS_UTILITY.format_error_stack || ' - ' ||
                           DBMS_UTILITY.format_error_backtrace, 1, 4000);
          prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, p_cod_persona, null);

      END;

      if nvl(v_existe_c, 'N') = 'N' then
        p_cod_error := 4;
        p_mensaje   := 'No se encontró la cuenta ';
        return;
      end if;

      BEGIN
        Select 'S'
          into v_existe_p
          from ba_personas t
         where t.cod_persona = p_cod_persona;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_existe_p := 'N';
        WHEN OTHERS THEN
          p_cod_error   := 5;
          p_mensaje     := 'Error al buscar persona ' || p_cod_persona;
          v_log_mensaje := substr('Error al buscar persona ' || p_cod_persona || ' ' ||
                           DBMS_UTILITY.format_error_stack || ' - ' ||
                           DBMS_UTILITY.format_error_backtrace, 1, 4000);
          prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, p_cod_persona, null);

      END;

      if nvl(v_existe_p, 'N') = 'N' then
        p_cod_error := 6;
        p_mensaje   := 'No se encontró la persona ';
        return;
      end if;

      if nvl(v_existe_p, 'N') = 'S' and nvl(v_existe_c, 'N') = 'S' then
        BEGIN
          Select 'S'
            into v_existe_r
            from GE_CTA_CLIENTES t
           where t.nro_cuenta = p_nro_cuenta
             and t.cod_persona = p_cod_persona;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_existe_r := 'N';
          WHEN OTHERS THEN
            p_cod_error   := 7;
            p_mensaje     := 'Error al buscar Cuenta ' || p_cod_persona;
            v_log_mensaje := substr('Error al buscar Cuenta ' || p_cod_persona || ' ' ||
                             DBMS_UTILITY.format_error_stack || ' - ' ||
                             DBMS_UTILITY.format_error_backtrace, 1, 4000);
            prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, p_cod_persona, null);

        END;
        if nvl(v_existe_r, 'N') = 'S' then
          p_cod_error := 8;
          p_mensaje   := 'La relacion de firmante ' || p_cod_persona ||
                         ' ya existe con la cuenta ' || p_nro_cuenta;
          return;
        else
            BEGIN
               select j.naturaleza
                 into v_naturaleza
                 from ge_cta_clientes gc, ba_per_juridicas j
                where gc.relacion = 'P'
                  and j.cod_persona = gc.cod_persona
                  and gc.nro_cuenta = p_nro_cuenta;
            EXCEPTION
              when no_data_found then
                v_naturaleza := 'X';
              when others then
                v_naturaleza := 'X';
            END;
            if nvl(v_naturaleza, 'X') = fug_obt_pardinamico('VAL_MIN_EMP_UNI') then
              v_relacion := 'O';
            end if;
          BEGIN
            insert into GE_CTA_CLIENTES
              (COD_PERSONA,
               NRO_CUENTA,
               DIG_VERIFICADOR,
               COD_OFICINA,
               COD_MODULO,
               COD_MODALIDAD,
               RELACION,
               EST_RELACION)
            values
              (p_cod_persona,
               p_nro_cuenta,
               v_dig_verificador,
               v_cod_oficina,
               v_cod_modulo,
               v_cod_modalidad,
               v_relacion,
               'A');
          EXCEPTION
            WHEN OTHERS THEN
              p_cod_error   := 9;
              p_mensaje     := 'Error al insertar Cuenta Cliente ';
              v_log_mensaje := substr('Error al insertar Cuenta Cliente ' ||
                               DBMS_UTILITY.format_error_stack || ' - ' ||
                               DBMS_UTILITY.format_error_backtrace, 1, 4000);
              prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', v_log_mensaje, null, null);

          END;
        end if;
      end if;

      if nvl(p_cod_error, 0) = 0 then
        p_cod_error := 0;
        p_mensaje   := null;
      else
        prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', substr(v_log_mensaje, 1, 4000), null, null);
      end if;
      
    END IF; -- Fin sociedades

    EXCEPTION
      WHEN OTHERS THEN
        v_log_mensaje := substr(DBMS_UTILITY.format_error_stack || ' - ' ||
                         DBMS_UTILITY.format_error_backtrace, 1, 4000);
        p_cod_error   := 99;
        p_mensaje     := 'Ocurrio un error inesperado durante el proceso';
        prg_ins_log_programas('PAG_FIR.PR_ASO_FIRMAS', substr(v_log_mensaje, 1, 4000), null, null);
    END;

    procedure pr_alt_fir_cuentas(p_nro_cuenta in ah_cta_vistas.nro_cuenta%type,
                                 p_cod_error  out number,
                                 p_msj_error  out varchar2) is

      g_lugar      varchar2(250);
      g_msj_error  varchar2(4000);
      g_cod_error  number(3) default 0;
      v_can_firmas number;
      v_existe     varchar2(1);

    begin
      g_msj_error := ' ';
      g_cod_error := 0;
      begin
        pre_ini_aplicacion;
      end;
      PAE_CNF.G_PROGRAMA := 'PR_ALT_FIR_CUENTAS';

      -- valida que los parametros no sean null
      if p_nro_cuenta is not null then
        -- verifica que exista en ah_cta_vistas
        begin
          select 'S'
            into v_existe
            from ah_cta_vistas ss
           where nro_cuenta = p_nro_cuenta;
        exception
          when others then
            v_existe := 'N';
        end;

        if v_existe = 'S' then
          -- conteo firmas
          begin
            select count(*)
              into v_can_firmas
              from ge_cta_clientes ss
             where nro_cuenta = p_nro_cuenta
               and relacion in ('O', 'Y')
               and ss.cod_modulo = '3'
               and ss.nro_cuenta in
                   (select s.nro_cuenta from ah_cta_vistas s);
          exception
            when others then
              v_can_firmas := 0;
          end;
          -- actualiza independientemente que v_can_firmas sea 0
          --if v_can_firmas > 0 then
          begin
            update ah_cta_vistas pp
               set pp.can_fir_registradas = v_can_firmas
             where pp.nro_cuenta = p_nro_cuenta;
          exception
            when others then
              g_cod_error := '008';
              g_lugar     := 'Actualiza tabla ah_cta_vistas cuentas.';
              g_msj_error := 'Error al actualizar cantidad de firmas de ah_cta_vistas.';
              prg_ins_log_programas('PAG_FIR.PR_ALT_FIR_CUENTAS',
                                    g_msj_error,
                                    p_nro_cuenta,
                                    null);

          end;
          --end if;
        else
          g_cod_error := '008';
          g_lugar     := 'Verificacion primera cuenta del parametro.';
          g_msj_error := 'Numero de cuenta no es valido.';
          prg_ins_log_programas('PAG_FIR.PR_ALT_FIR_CUENTAS',
                                g_msj_error,
                                p_nro_cuenta,
                                null);
        end if;
      else
        g_cod_error := '008';
        g_lugar     := 'Actualiza tabla ah_cta_vistas';
        g_msj_error := 'Error. El parametro p_nro_cuenta no puede ser nulo.';
        prg_ins_log_programas('PAG_FIR.PR_ALT_FIR_CUENTAS',
                              g_msj_error,
                              p_nro_cuenta,
                              null);
      end if;

      if nvl(g_cod_error, '000') <> '000' then
        p_cod_error := g_cod_error;
        p_msj_error := g_msj_error;
      else
        g_cod_error := '0';
        g_msj_error := null;

        p_cod_error := g_cod_error;
        p_msj_error := g_msj_error;
      end if;
    end;

end PAG_FIR;
/
