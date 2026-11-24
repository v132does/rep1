CREATE OR REPLACE PROCEDURE IT.PRP_PROC_PRESTAMOS_RES_04
(p_tipo in varchar)  --Tipo ('C','N')
is
  v_lugar varchar2(3000);
  v_existe varchar2(1):='N';
  v_nro_cta_nueva varchar2(100);
  v_error        varchar2(3000):='N';
  v_resultado    varchar2(3000):='OK';
  v_mensaje varchar2(3000);
  v_procesar  varchar2(1):='S';
cursor cur_cancelaciones is
  select a.nro_cuenta from PR_SOL_INC_RES4 a
                  where a.can_cta_ant='N'
                    and a.error is null
                          order by 1;
cursor cur_nuevos is
select a.nro_cuenta from PR_SOL_INC_RES4 a
                  where a.gen_cta_nueva='N'
                     and a.can_cta_ant='S'
                     and a.error is null
                         order by 1;

PROCEDURE pr_ins_log_error(p_nro_cuenta   pr_cta_pre_can_log.nro_cuenta%type,
                              p_mensaje      pr_cta_pre_can_log.msg_error%type,
                              p_tipo       varchar2)
    is
    pragma autonomous_transaction;
    BEGIN
      BEGIN
      if p_tipo='C' then
         update PR_SOL_INC_RES4 A
          set a.error =p_tipo||'-'||p_mensaje,
            a.can_cta_ant='N'
           where a.nro_cuenta= p_nro_cuenta;
     elsif p_tipo='N' then
        update PR_SOL_INC_RES4 A
          set a.error =a.error||' '||p_tipo||'-'||p_mensaje,
            a.gen_cta_nueva='N'
           where a.nro_cuenta= p_nro_cuenta;
     end if;

     EXCEPTION
        WHEN OTHERS THEN
          null;
      END;
      commit; -- este commit solo afecta a la transaccion autonoma
    END;
-----Inicio de Proceso Principal -----------------------
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;


if p_tipo= 'C' then

    for z in cur_cancelaciones loop
       v_mensaje:= null;
       v_error:='N';
       v_procesar:='S';
       v_existe:='N';
       v_lugar:='Validamos que exista la Cuenta : ' ||z.nro_cuenta ;
       --Validamos que exista la cuenta
          v_existe:='N';
          BEGIN
             SELECT 'S'
               into v_existe
               FROM pr_cta_prestamos a, ge_cta_clientes c
                where a.nro_cuenta= z.nro_cuenta
                  and a.nro_cuenta= c.nro_cuenta
                  and c.cod_modulo= a.cod_modulo
                  and c.relacion='P'
                  and c.cod_modalidad=a.cod_modalidad;

          EXCEPTION
             WHEN no_data_found THEN
               v_existe:='N';
               v_error:='S';
               v_procesar:='N';
               v_mensaje := v_lugar||''|| sqlerrm;
               pr_ins_log_error(z.nro_cuenta, v_mensaje,p_tipo);
             WHEN others THEN
               v_existe:='N';
               v_error:='S';
               v_procesar:='N';
               v_mensaje := 'Otro Error-'||v_lugar||''|| sqlerrm;
               pr_ins_log_error(z.nro_cuenta, v_mensaje,p_tipo);

            END;
      ---LLamamos al proceso de Cancelacion
      v_lugar:= 'Ejec.Proc.Canc: ' || z.nro_cuenta;
      if v_error='N' and v_procesar='S' and v_existe='S' then
          PRG_CAN_CUO_RES4_v2(z.nro_cuenta,v_error);
          --Si hay error Guardamos
          if substr(v_error,1,1) <>  'N' then
              v_mensaje := 'Al Ej.Canc: '||z.nro_cuenta||' - '||v_error;
              pr_ins_log_error(z.nro_cuenta, v_mensaje,p_tipo);
          End if;
      end if;
    end loop;

 elsif p_tipo='N' THEN
  --Para Nuevos Prestamos
  for z in cur_nuevos loop
   v_mensaje:= null;
   v_error:='N';
   v_procesar:='S';
   v_existe:='N';
   v_lugar:='Validamos que exista la Cuenta: ' ||z.nro_cuenta ;
   --Validamos que exista la cuenta
        v_existe:='N';
          BEGIN
             SELECT 'S'
               into v_existe
               FROM pr_cta_prestamos a, ge_cta_clientes c
                where a.nro_cuenta= z.nro_cuenta
                  and a.nro_cuenta= c.nro_cuenta
                  and c.cod_modulo= a.cod_modulo
                  and c.relacion='P'
                  and c.cod_modalidad=a.cod_modalidad;

          EXCEPTION
             WHEN no_data_found THEN
               v_existe:='N';
               v_error:='S';
               v_procesar:='N';
               v_mensaje := v_lugar||''|| sqlerrm;
               pr_ins_log_error(z.nro_cuenta, v_mensaje,p_tipo);
             WHEN others THEN
               v_existe:='N';
               v_error:='S';
               v_procesar:='N';
               v_mensaje := 'Otro Error-'||v_lugar||''|| sqlerrm;
               pr_ins_log_error(z.nro_cuenta, v_mensaje,p_tipo);

           END;
        ---Llamamos a proceso
      if v_error='N' and v_procesar='S'and v_existe='S' THEN
              v_nro_cta_nueva:=NULL;
              v_lugar:= 'Ejec.Proc.Gen: ' ||z.nro_cuenta;
              PRP_GEN_PRESTAMOS_RES_04(z.nro_cuenta,v_resultado,v_nro_cta_nueva);
              if v_nro_cta_nueva is null  then
                v_error:='S';
                v_mensaje := v_resultado||' '||z.nro_cuenta;
                pr_ins_log_error(z.nro_cuenta, v_mensaje,p_tipo);
              end if;
       end if;


 end loop;




END IF;

end PRP_PROC_PRESTAMOS_RES_04;
/

