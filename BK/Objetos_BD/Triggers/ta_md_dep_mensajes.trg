CREATE OR REPLACE TRIGGER IT.TA_MD_DEP_MENSAJES
  after insert on MD_DEP_MENSAJES
  for each row
declare
  v_hor_recepcion VARCHAR2(8);
  v_cod_ejecucion md_dep_msj_automaticos.cod_ejecucion%type;
  v_nro_orden     md_dep_msj_automaticos.nro_orden%type;
  v_cod_msj_swift sb_snp_mensajes.cod_mensaje%type;
  v_exi_msj_enviado varchar2(1);
  v_cod_msj_env_bcp sb_snp_tip_mensajes.cod_mensaje%type;
  v_tie_pedido varchar2(1);
  v_ref_campo2    sb_snp_mensajes.campo%type;
  v_val_campo2    sb_snp_mensajes.valor%type;
begin
   if inserting and (:new.cod_mensaje = 'MT941' and :new.campo = '64') then
      --Ver si fue Pedido a Requerimiento--
      select DECODE(NVL(COUNT(*),0),0,'N','S')
        into v_tie_pedido
        from MD_DEP_MSJ_PEDIDOS x
       where x.nro_ref_pedido = :new.nro_ref_externa;

      if v_tie_pedido = 'S' then
        null;
         --pam_dep.pr_gen_pre_deposito(:new.valor, :new.nro_ref_externa);
      else
         --Actualiza archivo enviado--
         v_cod_msj_swift := :new.cod_mensaje;
         --PAM_DEP.PR_OBT_DAT_MSJ_ACTUAL('MT920', 'E', :new.nro_ref_externa, v_exi_msj_enviado, v_cod_ejecucion, v_nro_orden, v_cod_msj_env_bcp);
         if v_exi_msj_enviado = 'S' then
            v_hor_recepcion := TO_CHAR(SYSDATE,'HH24:MI:SS');
            --SPI obtener cuenta origen de la consulta de saldo (mt920)
            begin
               select a.campo, rtrim(ltrim(a.valor))
                 into v_ref_campo2, v_val_campo2
                 from sb_snp_mensajes a
                where trunc(fec_insercion) = trunc(sysdate)
                  and a.cod_mensaje = :new.cod_mensaje
                  and a.campo = '25' --Identificador de cuenta
                  and a.nro_referencia = :new.nro_referencia
                  and rownum = 1;
            exception
              when others then
                raise_application_error(-20006,'Error al obt. campo 25 '||v_ref_campo2||'-'||v_val_campo2);
            end;
            --PAM_DEP.PR_CON_ENV_AUTOMATICO('R', :new.nro_ref_externa, v_hor_recepcion, v_cod_ejecucion, v_nro_orden,
                                          --v_cod_msj_swift, :new.nro_referencia, :new.campo, :new.valor, v_ref_campo2, v_val_campo2);
            if v_nro_orden = 1 then
               --PAM_DEP.PR_ENV_ARC_DEP_BCP(v_cod_ejecucion, v_val_campo2);
               null;
            end if;
         end IF;
      end if;
   END IF;
exception
   when others then
     null;
end TA_MD_DEP_MENSAJES;
/

