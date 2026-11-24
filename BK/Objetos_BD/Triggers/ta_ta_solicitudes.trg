CREATE OR REPLACE TRIGGER IT.TA_TA_SOLICITUDES
 AFTER DELETE OR INSERT OR UPDATE
 ON TA_SOLICITUDES
 FOR EACH ROW
DECLARE
  v_tip_persona ba_personas.tipo%type;
  v_not_ext_tar varchar2(1);

/* Inserta las gestiones de la solicitud. */
PROCEDURE LP_INS_PR_SOL_GES
 (RP_RSGES IN TA_SOL_GESTIONES%ROWTYPE
 );
   r_psges ta_sol_gestiones%rowtype;

/* Inserta las gestiones de la solicitud. */
PROCEDURE LP_INS_PR_SOL_GES
 (RP_RSGES IN TA_SOL_GESTIONES%ROWTYPE
 )
 IS
BEGIN
   insert into ta_sol_gestiones
     (nro_solicitud, cod_estado, fecha,
      cod_usuario, observacion)
   values
     (rp_rsges.nro_solicitud, rp_rsges.cod_estado, rp_rsges.fecha,
      rp_rsges.cod_usuario, rp_rsges.observacion);
END;

/* Actualiza estado del informe de crédito. */
PROCEDURE LP_ACT_GE_INF_CREDITOS(P_ESTADO IN VARCHAR2)
 IS
BEGIN
   update ge_inf_creditos
   set estado = P_ESTADO
   where nro_solicitud = :new.nro_solicitud;
   exception
      when no_data_found then
         null;
      when others then
         raise_application_error(-20000,'Act. Informe Crédito. '||sqlerrm);
END;

BEGIN

  if inserting
   or (updating and
       :new.cod_estado <> :old.cod_estado) then
      --- Actualizar historial de gestiones
      r_psges.nro_solicitud := :new.nro_solicitud;
      r_psges.cod_estado    := :new.cod_estado;
      r_psges.fecha         := sysdate;
      r_psges.cod_usuario   := user;
      r_psges.observacion   := :new.observacion;
      lp_ins_pr_sol_ges(r_psges);
      -- genera notificaciones de extracto Click de las solicitudes ingresadas por ITGF
      begin
        select tipo
          into v_tip_persona
          from ba_personas
         where cod_persona = :new.cod_persona;
      exception
        when others then
          v_tip_persona := 'J';
      end;

      if :new.cod_estado = 'APR' and v_tip_persona = 'F' then
        v_not_ext_tar := nvl(fug_obt_pardinamico('EXC_NOT_EXT_TAR', :new.cod_modulo, :new.cod_modalidad),'N');
        
        if nvl(v_not_ext_tar,'X') <> 'S' then 
          declare
            v_ret_extracto varchar2(1);
            v_mot_ret_extracto number(3);
            v_tip_extracto varchar2(1);
          Begin
            Begin
              select d.val_parametro
                into v_ret_extracto
                from ba_tab_dat_adicionales d
               where tab_relacion = 'TA_SOLICITUDES'
                 and parametro = 'RET_EXTRACTO'
                 and referencia = :new.nro_solicitud;
            exception
              when others then
                v_ret_extracto := null;
            end;

            if v_ret_extracto is not null then
              Begin
                select d.val_parametro
                  into v_mot_ret_extracto
                  from ba_tab_dat_adicionales d
                 where tab_relacion = 'TA_SOLICITUDES'
                   and parametro = 'MOT_RET_EXTRACTO'
                   and referencia = :new.nro_solicitud;
              exception
                when others then
                  v_ret_extracto := 5;
              end;
              
              if v_ret_extracto = 'S' then
                 v_tip_extracto := 'N';
              else
                 v_tip_extracto := 'S';
              end if;

              prg_gen_not_extracto( 'ITGF', v_tip_extracto, :new.cod_modulo, null, :new.cod_persona, nvl(V_mot_ret_extracto,5));
            end if;
          end;
        END IF;	
     end if;
   end if;

  -- Cambio solicitado por MIS, la oficina a guardar debe ser la oficina del oficial de la cuenta - RABP 08/10/2013
   if inserting then
      if :new.cod_oficina != FUG_OBT_OFI_OFICIAL(:new.Cod_Persona) then
         raise_application_error(-20000,'La Oficina de la cuenta debe llevar la oficina del Oficial: '||fue_obt_des_oficina(FUG_OBT_OFI_OFICIAL(:new.Cod_Persona))||' ('||FUG_OBT_OFI_OFICIAL(:new.Cod_Persona)||')');
      End If;
   End If;

   /* Para actualizar el estado de las solicitudes que tiene informe de crédito. */
   if updating then
      if nvl(fug_obt_pardinamico('SOL_INF_CRE_ADMISION', :new.cod_modulo, :new.cod_modalidad), 'N') = 'S' then
          if :new.cod_estado <> :old.cod_estado and :new.cod_estado <> 'PAN' then
             LP_ACT_GE_INF_CREDITOS('B');
          else if :new.cod_estado <> :old.cod_estado and :new.cod_estado = 'PAN' then    
             LP_ACT_GE_INF_CREDITOS('A');
          end if;   
          end if;
      end if;    
   end if;

END;
/

