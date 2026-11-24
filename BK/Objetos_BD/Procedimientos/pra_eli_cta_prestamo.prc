CREATE OR REPLACE PROCEDURE IT.pra_eli_cta_prestamo IS

cursor cuentas is 
  select a.nro_cuenta,a.cod_modulo,a.fec_apertura, a.fec_ult_movimiento
    from ah_cta_vistas a
   where a.estado = 'A'
     and a.fec_ult_movimiento is not null
     and a.cod_sub_modalidad = 9
     and a.reg_firma = 'ALTA AUTOMATICA PARA PRESTAMO'
     /*and exists (select 1
                   from pr_solicitudes p
                  where p.nro_cta_debito = a.nro_cuenta
                    and p.estado in ('N','R') --tiene que ser Rechazado o Cancelado
                 )*/
     and a.fec_apertura <= pag_cal.FU_OBT_FEC_ACTUAL(3)
     and not exists (select 1
                       from pr_cta_prestamos pe
                      where pe.nro_cta_debito = a.nro_cuenta
                        and pe.estado != 'N' --tiene que ser Rechazado o Cancelado
                     );

v_cod_programa ba_programas.cod_programa%type;
v_nro_cuenta   ah_cta_vistas.nro_cuenta%type;
v_error        varchar2(4000);
function lf_ver_tie_solicitud(p_nro_cuenta in ah_cta_vistas.nro_cuenta%type) return varchar is
  v_existe varchar2(1) := 'N';
  begin
    select 'S'
      into v_existe
      from pr_solicitudes p
     where p.nro_cta_debito = p_nro_cuenta
       and p.estado not in ('N','R');
    return v_existe;
  exception
    when no_data_found then
      v_existe := 'N';
      return v_existe;
    when too_many_rows then
      v_existe := 'S';
      return v_existe;
     when others then
      v_existe := 'N';
      return v_existe;
  end;

-- se anula el DA si esta vinculado a una cuenta de prestamo Cancelada. DYDMR-11770
procedure lp_act_deb_aut_vinculado (p_nro_cuenta in ah_cta_vistas.nro_cuenta%type) is
  begin
    update pr_cta_prestamos p
      set p.nro_cta_debito = null, p.cob_automatico ='N'
    where p.nro_cta_debito = p_nro_cuenta
      and p.estado = 'N';  -- si esta cancelado desvincula 
   exception
     when others then
       raise_application_error('-20000','Error al actualizar DA de Prestamo '||p_nro_cuenta||' - '||sqlerrm);   
  end;
--- se cancela la tarjeta de debito vinculado a la cuenta.
procedure lp_act_est_tar_debito(p_nro_cuenta in ah_cta_vistas.nro_cuenta%type) is
   begin
     update ah_tar_debitos a
        set a.cod_est_solicitud = 16
      where a.nro_cuenta = p_nro_cuenta;
   exception
     when others then
       raise_application_error('-20000','Error al actualizar estado de la tarjeta de debito '||p_nro_cuenta||' - '||sqlerrm);
   end;

-- DYDMR-11353 se agrega notificacion via mail en caso de error para que no pare el proceso.
procedure lp_reg_error(p_error varchar2)
  is
   -- Variables para mail
   v_hin_mail ge_ra_log_mail.hor_inicio%type;
   v_hfi_mail ge_ra_log_mail.hor_fin%type;
   v_det_error ge_ra_log_mail.det_error%type;
   v_para      varchar2(1000) := fug_obt_pardinamico('ENV_EMA_GUA_CIERRE');
   v_asunto    varchar2(100) :=  'Error proceso pra_eli_cta_prestamo';
   PRAGMA AUTONOMOUS_TRANSACTION;

   BEGIN
     v_hin_mail := to_char(sysdate, 'hh24:mi:ss');
     it_mail.mail(fug_obt_dir_correo,v_para ,v_asunto, p_error);
     v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');
   EXCEPTION
     when others then
       v_det_error := substr(sqlerrm, 1, 4000);
       INSERT INTO ge_ra_log_mail
       (fec_envio, nom_archivo, dir_correo, mensaje,
        det_error, hor_inicio, hor_fin)
       VALUES
       (SYSDATE, null, v_para, substr(v_asunto||chr(10)|| p_error,1,2000),
        substr(v_det_error,1,4000), v_hin_mail, v_hfi_mail);
     commit;
   END;

BEGIN  
  --
  v_cod_programa     := pae_cnf.FU_OBT_COD_PROGRAMA;
  PAE_CNF.G_PROGRAMA := 'GPELICTA';
  --
  for c in cuentas loop
    v_nro_cuenta := c.nro_cuenta;
    -- para desvincular de prestamo cancelado
    lp_act_deb_aut_vinculado(c.nro_cuenta);
    --
    if lf_ver_tie_solicitud(c.nro_cuenta) = 'N' then
      begin
        lp_act_est_tar_debito(c.nro_cuenta);
        prg_eli_cuenta(c.nro_cuenta,c.cod_modulo,'Eliminacion automatica de Cuentas para Prestamos.');
        -- agregamos que comitee cada cuenta eliminada para evitar bloqueos  DYDMR-11353
        commit;
        --
      exception
        when others then
          --raise_application_error('-20000','Error al eliminar Cuenta: '||c.nro_cuenta||' - '||sqlerrm);
          -- DYDMR-11353
          v_error :='Error al eliminar Cuenta: '||c.nro_cuenta||' - '||sqlerrm;
          lp_reg_error(v_error);
          -- deshacemos cualquier cambio hecho y continuamos con el siguiente registro.
          rollback;
          goto siguiente;
          ---
      end;
    end if;
    
    <<siguiente>>
    v_nro_cuenta := null;
  end loop;
  --
  PAE_CNF.G_PROGRAMA :=v_cod_programa;
  --
 exception
        when others then
          PAE_CNF.G_PROGRAMA :=v_cod_programa;
          raise_application_error('-20000','Error al eliminar Cuenta: '||v_nro_cuenta||' - '||sqlerrm);    
END pra_eli_cta_prestamo;
/

