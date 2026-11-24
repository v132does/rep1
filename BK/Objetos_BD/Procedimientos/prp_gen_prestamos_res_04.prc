CREATE OR REPLACE PROCEDURE IT.PRP_GEN_PRESTAMOS_RES_04(
p_nro_CUENTA in varchar2 default null,
p_resultado out varchar2,
p_nro_cta_nueva out varchar2)
is
  --pragma autonomous_transaction;
  v_lugar varchar2(3000);
  v_error varchar2(3000);
  v_nro_solicitud number (30);
  v_nro_cuenta varchar2(300);
  v_fec_pri_vto date;
  v_dia_vto varchar2(10);
  v_fec_pri_vto_cal varchar2(20);
  v_fec_inicio date:= pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_mto_prestamo number(18,4);
  v_cod_sub_modalidad varchar2(10):='99';
  v_can_cuotas number(10):=18;
  v_nro_cta_nueva varchar2(100);
  v_nro_cta_proc  varchar2(100);
  v_cod_per_proc  varchar2(100);
  v_est_solicitud varchar2(10);
  v_cantidad      number(10);
  v_cant_reg      number(18);
  v_nro_cuenta_debito varchar2(20);
  v_nro_linea   varchar(100);
  v_deb_automatico varchar2(1);
  v_resultado    varchar2(3000):='OK';
  v_cod_gar_pre_ant varchar2(10);
  v_nro_gar_pre_ant varchar2(10);
  v_hor_pre         varchar2(12);
  v_cod_modalidad    varchar2(10);
  v_cod_rub_economico  varchar2(10);
cursor cur_universo is
   select a.* from pr_cta_pre_can_res4 a
      where a.nro_cta_nueva is null
         and a.nro_sol_nueva is null
         and a.nro_cuenta= nvl(v_nro_cuenta,a.nro_cuenta)
              order by a.nro_cuenta;


cursor cur_datos is
  select  b.cod_rub_economico,b.cod_sec_credito,a.nro_cuenta,a.nro_cta_debito,
  a.nro_cta_renovada,a.cod_modulo,a.cod_modalidad, a.cod_oficina,a.cod_moneda, b.deb_automatico
   from pr_cta_prestamos a, pr_solicitudes b
    where a.nro_cuenta=v_nro_cta_proc
      and nvl(a.nro_sol_renovada,a.nro_solicitud)= b.nro_solicitud;

begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;

--delete from PR_PRO_RES_LOG a;
v_cant_reg:=0;

if  p_nro_CUENTA is null then
   v_nro_cuenta:=null;
else
   v_nro_cuenta:=p_nro_CUENTA;
end if;

for z in cur_universo loop
  v_lugar:= 'Inicio proceso principal: ' || z.nro_cuenta;
  v_mto_prestamo:=0;
  v_nro_cta_proc:= z.nro_cuenta ;
  v_cod_per_proc:= z.cod_persona;
  --if nvl(z.tot_deu_200320,0) > 0 then
  if nvl(z.tot_deuda,0) > 0 then
    v_mto_prestamo:= nvl(z.tot_deuda,0);--nvl(z.tot_deu_200320,0);
  else
    v_mto_prestamo:= nvl(z.sal_capital,0) + nvl(z.sal_interes,0)+nvl(z.mto_cargo,0)+nvl(z.mto_impuesto,0)+nvl(z.mto_mora,0)+
    nvl(z.mto_mor_int,0)+nvl(z.mto_punitorio,0);
  end if;
  for x in cur_datos loop
   begin
      v_fec_pri_vto:=null;
      v_dia_vto:=null;
      v_nro_cta_nueva:= null;
      v_nro_solicitud:= null;
      v_nro_cuenta_debito:= null;
      v_nro_linea:= null;
      v_deb_automatico:= null;
      v_cod_gar_pre_ant:=null;
      v_nro_gar_pre_ant:=null;
      v_cod_modalidad:=null;
      v_cod_rub_economico:= null;
      v_lugar:= 'Inicio Obtenenmos la Fecha de Vencimiento en Junio-Persona: '||p_nro_CUENTA;
           --Obtenemos la Fecha de Vencimiento del Mes de Junio Del prestamo actual, sino tiene, asumimos la fec_vto_Ult_Cuota
            begin
             select to_char(a.fec_vencimiento,'dd')
               into v_dia_vto
               from pr_cuotas a
                 where a.nro_cuenta= x.nro_cuenta
                  and to_char(a.fec_vencimiento,'mmyyyy')= '062020'
                    and rownum=1;
            exception
              when no_data_found then
                select to_char(max(a.fec_vencimiento),'dd')
                 into v_dia_vto
                  from pr_cuotas a
                     where a.nro_cuenta= x.nro_cuenta;
                end;
       v_lugar:= 'Seteamos la Fecha de Vencimiento en Junio-Persona: '||v_cod_per_proc;
       if v_dia_vto= '31' then
         v_dia_vto:= '30';
       end if;
       v_fec_pri_vto_cal:= trim(v_dia_vto || '/06/2020');
       v_fec_pri_vto:= to_date(v_fec_pri_vto_cal ,'dd/mm/yyyy');
       v_nro_solicitud:=null;
       v_nro_cuenta:= null;
       --Obtenemos una de las garantias del prestamo anterior para asignar al nuevo
        begin
              SELECT w.cod_garantia, w.nro_garantia
              into v_cod_gar_pre_ant,v_nro_gar_pre_ant
          FROM
            ( select z.cod_garantia,z.nro_garantia
            from pr_cta_garantias z
                 where z.nro_cuenta= x.nro_cuenta
                     order by z.fec_insercion desc) w
                WHERE  rownum = 1 ;
          exception
              when no_data_found then
                v_cod_gar_pre_ant:=null;
                v_nro_gar_pre_ant:=null;
              when others then
                v_cod_gar_pre_ant:=null;
                v_nro_gar_pre_ant:=null;
          end;
       --Buscamos la modalidad a enviar *********
        select decode (x.cod_modalidad, 
                         609,909,
                         612,912,
                         621,921,
                         61,961,
                         65,965,
                         68,968,
                         673,973,
                         681,981,
                         --
                         69,969,
                         690,990, 
                         691,991,
                        x.cod_modalidad)
        into v_cod_modalidad
          from dual;
       --enviamos el rubro anterior 
       v_cod_rub_economico:= x.cod_rub_economico;
       --******************************************


       v_lugar:= 'Procesando la Solicitud; '||v_cod_per_proc;
       prp_gen_atm_solicitud_res_04(v_cod_per_proc,
                                      v_cod_modalidad,--x.cod_modalidad,
                                      x.cod_moneda,
                                      v_mto_prestamo,--monto
                                      v_can_cuotas,--cuota
                                      'S',--grabar
                                      'B', --B-BRUTO o N-NETO
                                      v_fec_inicio,
                                      nvl(v_fec_pri_vto,null),--null,--primer vencimiento
                                      null,--tasa
                                      null,--canal
                                      null,--campaña
                                      'Prestamo Aprobado Res 04 BCP' ,
                                      null,
                                      null,
                                      null,
                                      null,
                                      x.nro_cta_debito, --La misma ctade Débito del Préstamo Actual
                                      v_cod_sub_modalidad, --Enviamos la Nueva Sub_Modalidad (99)
                                      v_cod_rub_economico,--x.cod_rub_economico, --Rubro economico de Solicitud anterior
                                      x.cod_sec_credito, --Sector economico
                                       nvl(x.deb_automatico,'N') , --Enviamos si el anterior prestamo tenia deb_automatico o no.
                                      v_cod_gar_pre_ant, --cod garantia prest anterior
                                      v_nro_gar_pre_ant, --nro garantia prest anterior
                                      v_nro_solicitud);


           v_lugar:= 'Desembolsando; '||v_cod_per_proc || ' Nro.Sol: ' ||v_nro_solicitud;
          IF v_nro_solicitud is not null then
             execute immediate 'alter trigger TB_GE_CTA_CLIENTES disable';
                v_hor_pre:=null;
                prp_des_atm_prestamo_res_04(v_cod_per_proc, v_mto_prestamo, x.nro_cta_debito, v_nro_solicitud, x.nro_cuenta,v_nro_cta_nueva,v_hor_pre );
             execute immediate 'alter trigger TB_GE_CTA_CLIENTES enable';
             if v_nro_cta_nueva is not null then
                  v_lugar:='Actualizando Numero de Cta:'|| x.nro_cuenta ||' Cta.Nueva: '||v_nro_cuenta;
                  --Obtenemos Eln nro de cuenta del prestamo anterior
                   begin
                      select d.nro_cta_debito, d.nro_linea, d.cob_automatico
                       into v_nro_cuenta_debito, v_nro_linea,v_deb_automatico
                       from pr_cta_prestamos d
                        where d.nro_cuenta= x.nro_cuenta;
                    exception
                      when no_data_found then
                       v_nro_cuenta_debito:= null;
                       v_nro_linea:= null;
                        v_deb_automatico:= null;
                       when others then
                        v_nro_cuenta_debito:= null;
                        v_nro_linea:= null;
                        v_deb_automatico:= null;
                    end;
                  --Actualizamos datos del prestamo viejo
                   update pr_cta_prestamos a
                        set a.nro_cta_renovada= v_nro_cta_nueva
                       where a.nro_cuenta=  x.nro_cuenta;

                  --Actualizamos los datos del prestamo nuevo
                  update pr_cta_prestamos a
                        set a.nro_cta_renovada= null,
                              a.nro_cta_debito= v_nro_cuenta_debito,
                              a.nro_linea= v_nro_linea,
                              a.cob_automatico=v_deb_automatico,
                              a.COD_ORI_FONDO = DECODE(a.COD_MONEDA,'GS',1,'USD',2),
                              a.tip_renovacion = 'E'  --Reestructurado--
                       where a.nro_cuenta=  v_nro_cta_nueva;
                 --Actualizamos la Garantia del prestamo
                 delete from pr_cta_garantias a where a.nro_cuenta= v_nro_cta_nueva;
                 
                 prp_ins_gar_pre_res4(x.nro_cuenta, v_nro_cta_nueva,v_mto_prestamo );
 
                
                 --Actualizamos los datos de la tabla nueva
                 v_lugar:='Actualizando Nueva tabla:'|| x.nro_cuenta||' Cta.Nueva: '||v_nro_cuenta;
                  update pr_cta_pre_can_res4 a
                     set a.nro_cta_nueva= v_nro_cta_nueva,
                         a.nro_sol_nueva= v_nro_solicitud
                          where a.nro_cuenta= x.nro_cuenta;
                  
                   update PR_SOL_INC_RES4 A
                    set a.error =null,
                     a.Gen_Cta_Nueva='S',
                     a.nro_cta_nueva= v_nro_cta_nueva,
                     a.hor_nue=v_hor_pre
                     where a.nro_cuenta= x.nro_cuenta;
                  commit;
 
              end if;
           end if;
           P_RESULTADO:= V_RESULTADO;
           p_nro_cta_nueva:=v_nro_cta_nueva;
     exception
      when others then
        v_resultado :=v_lugar||sqlerrm;
        P_RESULTADO:= V_RESULTADO;
        p_nro_cta_nueva:=null;
     end;

   end loop;
end loop;





end PRP_GEN_PRESTAMOS_RES_04;
/

