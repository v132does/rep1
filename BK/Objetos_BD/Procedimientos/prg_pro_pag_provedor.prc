CREATE OR REPLACE PROCEDURE IT.PRG_PRO_PAG_PROVEDOR is
v_error    VARCHAR2(2) := '00' ;
-- DYDMR-3116 -- CN: 03/2016
v_fec_actual         ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(4);
Cursor c_cabecera is
 Select distinct trim(b.dato) cod_ente, b.nro_documento
 from bw_mov_pendientes b
 where to_date(substr(b.dato2,1,10),'DD/MM/YYYY') <= v_fec_actual -- OMM 21/11/2011 -- x si el pago se cargó el día anterior, igual debe procesar hoy
   and b.estado = 'C'
   and b.cod_tip_mensaje = '075'
   and exists (Select 1 from ge_pag_proveedores gp
               where gp.cod_ente = trim(b.dato)
                 and nvl(gp.nro_archivo, 0) = nvl(b.referencia, 0)
                 and gp.fec_pago = to_date(substr(b.dato2,1,10),'DD/MM/YYYY')
                 and gp.referencia = b.nro_documento
                 and gp.tip_carga = 'H'
                 and gp.estado in ('C', 'R'));
-- notificacion de mensaje
procedure lp_env_mail(p_mensaje in varchar2) is
  v_dir_correo ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DIR_MAIL_SET');
begin
  if nvl(pae_cnf.g_programa, 'x') <> 'GPPROFIN' then
     prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'), v_dir_correo, 'Proceso 451 - [PRG_PRO_PAG_PROVEDOR]', p_mensaje);
  end if;
exception
  when others then
    null;
end;
--
Begin
    if trunc(sysdate) <> v_fec_actual then
       lp_env_mail('Proceso no ejecutado por dia no habil');
       return;
    end if;
    
    pre_cam_for_numerico('.,');
    pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1;
    
    -- control de saldos para proveedores y notificacion
    pag_prv.pr_ver_operaciones;
        
    -- DYDMR-3116 -- CN: 03/2016             
    for cab in c_cabecera loop
      prg_cre_savepoint(cab.cod_ente||to_char(cab.nro_documento));   
      pag_prv.PR_PRO_PAGO(cab.cod_ente, cab.nro_documento, v_error);
      if v_error = '00' then
        commit ;
      else
        -- Solo realiza el rollback por cualquier eventualidad, en el paquete tambien envía mail        
        --rollback;
        prg_rol_savepoint(cab.cod_ente||to_char(cab.nro_documento));
      end if ;
    end loop;
    --
    lp_env_mail('Proceso finalizado correctamente en fecha '||to_char(v_fec_actual, 'dd/mm/yyyy'));
exception
   when others then
       lp_env_mail('Hubo un error en el proceso '||sqlerrm);
       raise_application_error(-20001,'PRG_PRO_PAG_PROVEDOR-'||sqlerrm);
end  ;
/

