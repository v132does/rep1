CREATE OR REPLACE FUNCTION IT.FUL_PRO_TRA_RECIBIDAS_GEN (P_NRO_LOTE IN NUMBER) return varchar2 IS

Cursor mensaje is
   SELECT trim(texto) texto
     FROM lc_swift_tmp
    order by nro_orden;
rg_tra lc_transferencias%rowtype;
msj mensaje%rowtype;
--v_cod_swi_corresponsal varchar2(100);
--v_sig_nro_sec_lote number (6);
v_can_reg_procesado number (6) := 0;
--v_cantidad number (6) := 0;
v_cod_pai_entidad number(4) := fug_obt_pai_entidad;
v_cod_swi_bco_cor_contra   varchar2(50);
v_cod_swi_bco_corresponsal varchar2(50);
--
PROCEDURE lp_ins_transferencias is
BEGIN
 if rg_tra.nro_ref_externa is not null then
  if rg_tra.tip_mensaje in ('CRED','SPRI') then
      rg_tra.nro_referencia := fue_obt_sig_secuencia('S_NRO_REF_'||lpad(rg_tra.cod_tip_referencia,3,0)||'');
        begin
          rg_tra.cod_rubro := ful_obt_rub_corresponsal(rg_tra.cod_bco_corresponsal,rg_tra.cod_moneda);
        exception
          when others then
            rg_tra.cod_rubro := null; -- ojo esto no debe pasar. ver porque da esto
        end;
        -- Asigno datos de Lote
         v_can_reg_procesado := nvl(v_can_reg_procesado,0) + 1;
      -- inserto el registro en transferencias
      insert into lc_transferencias
             (nro_referencia, cod_tip_referencia, cod_modulo, cod_modalidad, cod_oficina, fec_operacion,
              nro_operacion, cod_moneda, monto, saldo, cod_banco, nom_banco, cod_pai_banco, cod_ciu_banco,
              cod_aba_banco, cod_swi_banco, cod_bco_corresponsal, cod_per_solicitante, nom_solicitante,
              dir_solicitante, tel_solicitante, cod_pai_solicitante, cod_ciu_solicitante, cod_per_beneficiario,
              nom_beneficiario, dir_beneficiario, tel_beneficiario, cod_pai_beneficiario, cod_ciu_beneficiario,
              nro_cta_referencia, fec_ult_movimiento, fec_recepcion, cod_rubro, plazo, observacion,
              cod_uid_banco, nro_ref_externa, tip_mensaje, tip_cargo, cod_bco_cor_contra, nom_ciu_beneficiario,
              nom_ciu_solicitante, estado, msj_swift, fec_cam_estado, nro_doc_beneficiario, est_anterior,
              fec_valor,nro_sec_lote,tip_fondo, tip_motivo, tip_financiacion)
       values
             (rg_tra.nro_referencia, rg_tra.cod_tip_referencia, rg_tra.cod_modulo,
              rg_tra.cod_modalidad, rg_tra.cod_oficina, rg_tra.fec_operacion,
              rg_tra.nro_operacion, rg_tra.cod_moneda, rg_tra.monto, rg_tra.saldo, rg_tra.cod_banco,
              rg_tra.nom_banco, rg_tra.cod_pai_banco, rg_tra.cod_ciu_banco, rg_tra.cod_aba_banco,
              rg_tra.cod_swi_banco, rg_tra.cod_bco_corresponsal,
              rg_tra.cod_per_solicitante, rg_tra.nom_solicitante,
              rg_tra.dir_solicitante, rg_tra.tel_solicitante, rg_tra.cod_pai_solicitante,
              rg_tra.cod_ciu_solicitante, rg_tra.cod_per_beneficiario,
              nvl(rg_tra.nom_beneficiario,'** NO IDENTIFICADO **'), rg_tra.dir_beneficiario, rg_tra.tel_beneficiario,
              rg_tra.cod_pai_beneficiario, rg_tra.cod_ciu_beneficiario,
              rg_tra.nro_cta_referencia, rg_tra.fec_ult_movimiento, rg_tra.fec_recepcion,
              rg_tra.cod_rubro, rg_tra.plazo, rg_tra.observacion, rg_tra.cod_uid_banco,
              rg_tra.nro_ref_externa, rg_tra.tip_mensaje, rg_tra.tip_cargo,
              rg_tra.cod_bco_cor_contra, rg_tra.nom_ciu_beneficiario,
              rg_tra.nom_ciu_solicitante, rg_tra.estado, rg_tra.msj_swift, rg_tra.fec_cam_estado,
              rg_tra.nro_doc_beneficiario, rg_tra.est_anterior, rg_tra.fec_valor,p_nro_lote,
              rg_tra.tip_fondo, rg_tra.tip_motivo, rg_tra.tip_financiacion);
      -- inicializo los datos de vuelta
      rg_tra.nro_ref_externa := null;
      rg_tra.tip_mensaje := null;
      rg_tra.tel_beneficiario := null;
      rg_tra.fec_recepcion :=  null;
      rg_tra.cod_moneda    :=  null;
      rg_tra.monto         :=  null;
      rg_tra.saldo         := null;
      rg_tra.nom_solicitante := null;
      rg_tra.dir_solicitante := null;
      rg_tra.nom_ciu_solicitante := null;
      if rg_tra.tip_mensaje in ('SPRI') then
          rg_tra.cod_pai_banco := 20;
          rg_tra.cod_pai_solicitante := 20;
      end if;
      rg_tra.cod_ciu_solicitante := null;
      rg_tra.cod_ciu_banco := null;
      rg_tra.cod_bco_cor_contra := null;
      rg_tra.cod_bco_corresponsal := null;
      rg_tra.cod_swi_banco := null;
      rg_tra.cod_banco := null;
      rg_tra.nom_banco := null;
      rg_tra.cod_ciu_banco := null;
      rg_tra.nro_cta_referencia := null;
      rg_tra.cod_per_beneficiario  := null;
      rg_tra.cod_per_beneficiario := null;
      rg_tra.nro_doc_beneficiario := null;
      rg_tra.cod_per_beneficiario := null;
      rg_tra.nom_beneficiario := null;
      rg_tra.dir_beneficiario := null;
      rg_tra.nom_ciu_beneficiario := null;
      rg_tra.cod_ciu_beneficiario := null;
      rg_tra.cod_pai_beneficiario := null;
      rg_tra.observacion  := null;
      rg_tra.tip_cargo := null;
      rg_tra.msj_swift := null;
   -- RABP-CNF-25-09-2014: Seteamos los valores a Nulo --
      rg_tra.tip_fondo := null;
      rg_tra.tip_motivo := null;
      rg_tra.tip_financiacion := null;
    end if;
 end if;
END;

BEGIN
  --------------------------
  -- datos fijos
  rg_tra.cod_tip_referencia := '00';
  rg_tra.cod_modulo := 7;
  rg_tra.cod_modalidad := 75;
  rg_tra.cod_oficina := 1;
  rg_tra.fec_operacion := pag_cal.FU_OBT_FEC_ACTUAL(rg_tra.cod_modulo);
  rg_tra.nro_operacion := null;
  rg_tra.fec_recepcion := rg_tra.fec_operacion;
  rg_tra.estado := 'PE';
  rg_tra.fec_cam_estado := rg_tra.fec_operacion;
  rg_tra.est_anterior := null;
  rg_tra.cod_banco := fug_obt_cod_banco;
  rg_tra.plazo := fug_obt_pardinamico('DIA_SIN_CONFIRMAR');

  -- inicio de la lextura de los datos del mensaje
  for msj in mensaje loop
      rg_tra.msj_swift := rg_tra.msj_swift || chr(10) || msj.texto;
      if substr(msj.texto,1,2) = '-}' then -- fin del mensaje, ya se puede cargar los datos de la transferencia
         if instr(msj.texto,'{5:{MAC:') > 0 then -- solo se carga si tiene este pie de mensaje
            lp_ins_transferencias;
         end if;
      elsif substr(msj.texto,1,4) = ':20:' then  -- referencia externa
         rg_tra.nro_ref_externa := substr(msj.texto,5);
      elsif substr(msj.texto,1,5) = ':23B:' then -- tipo de transferencia SPRI(CONVENIO) CRED (COMUN)
         rg_tra.tip_mensaje := substr(msj.texto,6);
      elsif substr(msj.texto,1,5) = ':23E:' then -- telefono
         rg_tra.tel_beneficiario := substr(msj.texto,instr(msj.texto,'/')+1);
      elsif substr(msj.texto,1,5) = ':32A:' then -- fecha, moneda monto
         rg_tra.fec_recepcion := to_date(substr(msj.texto,6,6),'rrmmdd');
         rg_tra.fec_valor     := rg_tra.fec_recepcion;
         rg_tra.cod_moneda    := substr(msj.texto,12,3);
         rg_tra.monto         := to_number(replace(substr(msj.texto,15),',','.'));
         rg_tra.saldo         := rg_tra.monto;
      elsif substr(msj.texto,1,5) = ':50K:' then -- datos de remitente
         if substr(msj.texto,6,1) = '/' then -- es el nro de cuenta origen
            -- rg_tra.nro_cta_externa := substr(msj.texto,7);
            -- este dato falta guardar
            fetch mensaje into msj; -- leo sgite linea donde vendra el nombre
            rg_tra.nom_solicitante := substr(msj.texto,1);
            rg_tra.msj_swift := rg_tra.msj_swift || chr(10) || msj.texto;
         else
            rg_tra.nom_solicitante := substr(msj.texto,6);
         end if;
         fetch mensaje into msj;
         rg_tra.dir_solicitante := msj.texto;
         rg_tra.msj_swift := rg_tra.msj_swift || chr(10) || msj.texto;
         fetch mensaje into msj;
         rg_tra.msj_swift := rg_tra.msj_swift || chr(10) || msj.texto;
         if substr(msj.texto,1,1) between 'A' AND 'Z' then -- solo si hay ciudad
           rg_tra.nom_ciu_solicitante := msj.texto;
           fetch mensaje into msj;
           rg_tra.cod_ciu_banco := rg_tra.cod_ciu_solicitante;
           rg_tra.msj_swift := rg_tra.msj_swift || chr(10) || msj.texto;
         end if;
         if rg_tra.nom_ciu_solicitante is not null and rg_tra.tip_mensaje not in ('SPRI') then
            -- busco el pais y el codigo de ciudad si existe
           begin
              select cod_ciudad, cod_pais
                into rg_tra.cod_ciu_solicitante, rg_tra.cod_pai_solicitante
                from ba_ciudades
               where instr(rg_tra.nom_ciu_beneficiario,descripcion) > 0
                 and cod_pais <> v_cod_pai_entidad
                 and rownum = 1;
           exception
              when others then
                  rg_tra.cod_ciu_solicitante := null;
                  begin
                     select cod_pais
                       into rg_tra.cod_pai_solicitante
                       from ba_paises
                      where instr(rg_tra.nom_ciu_beneficiario,descripcion) > 0
                        and rownum = 1;
                  exception
                     when others then
                        rg_tra.cod_pai_solicitante := v_cod_pai_entidad;
                  end;
           end;
           rg_tra.cod_pai_banco := rg_tra.cod_pai_solicitante;
           rg_tra.cod_ciu_banco := rg_tra.cod_ciu_solicitante;
         end if;
      end if;
      if rg_tra.tip_mensaje in ('SPRI') then   -- españa
          --PAIS DEL SOLICITANTE ES SIEMPRE ESPAÑA
          rg_tra.cod_pai_solicitante := 20;
          rg_tra.cod_pai_banco       := 20;
          --':53A:' BANCO CORRESPONSAL DEL EMISOR ES SIEMPRE CAIXA
          rg_tra.cod_bco_cor_contra := 473;
          v_cod_swi_bco_cor_contra := 'CAIXESBB';
          --':54A:' BANCO CORRESPONSAL ES SIEMPRE CAIXA
          rg_tra.cod_bco_corresponsal := 473;
          v_cod_swi_bco_corresponsal := 'CAIXESBB';
          --':57A:' then -- BANCO ES SIEMPRE CAIXA
          rg_tra.cod_swi_banco :='CAIXESBB';
      else
          -- otras
          if substr(msj.texto,1,5) = ':53A:' then  --':53A:' BANCO CORRESPONSAL DEL EMISOR
             v_cod_swi_bco_cor_contra := substr(msj.texto,6);
             rg_tra.cod_bco_cor_contra := null;
          elsif substr(msj.texto,1,5) = ':54A:' then  --':53A:' BANCO CORRESPONSAL nuestro
             v_cod_swi_bco_corresponsal := substr(msj.texto,6);
             rg_tra.cod_bco_corresponsal := null;
          elsif  substr(msj.texto,1,5) = ':57A:' then  --':57A:' BANCO CORRESPONSAL nuestro
             rg_tra.cod_swi_banco := substr(msj.texto,6);
             rg_tra.cod_banco := null;
          end if;
          --
          begin
             select cod_banco
               into rg_tra.cod_bco_cor_contra
               from ge_bancos b
              where (b.cod_swift = v_cod_swi_bco_cor_contra or b.cod_aba = v_cod_swi_bco_cor_contra)
                and rownum = 1;
          exception
            when others then
                rg_tra.cod_bco_cor_contra := 317;
          end;
          --
          begin
             select cod_banco
               into rg_tra.cod_bco_corresponsal
               from ge_bancos b
              where (b.cod_swift = v_cod_swi_bco_corresponsal or b.cod_aba = v_cod_swi_bco_corresponsal)
                and rownum = 1;
          exception
            when others then
                rg_tra.cod_bco_corresponsal := 317;
          end;

      end if;
      begin
         select cod_banco, descripcion, x.cod_pais, x.cod_ciudad, b.cod_aba, b.cod_swift
           into rg_tra.cod_banco, rg_tra.nom_banco, rg_tra.cod_pai_banco, rg_tra.cod_ciu_banco, rg_tra.cod_aba_banco, rg_tra.cod_swi_banco
           from ba_direcciones x, ge_bancos b
          where (b.cod_swift = rg_tra.cod_swi_banco or b.cod_aba = rg_tra.cod_swi_banco)
            and b.cod_persona = x.cod_persona
            and x.principal = 'S'
            and rownum = 1;
      exception
        when others then
            rg_tra.cod_banco := null;
            rg_tra.nom_banco := 'BANCO '||rg_tra.cod_swi_banco||' NO IDENTIFICADO';
            rg_tra.cod_pai_banco := rg_tra.cod_pai_solicitante;
            rg_tra.cod_ciu_banco := rg_tra.cod_ciu_solicitante;
      end;

      if substr(msj.texto,1,4) = ':59:' then -- beneficiario
         if instr(upper(msj.texto),upper('/ident.')) = 0 then -- nro_cuenta
            rg_tra.nro_cta_referencia := substr(msj.texto,instr(msj.texto,'/')+1);
            --Valido el numero de cuenta
            if length(rg_tra.nro_cta_referencia) > 10 then
               begin
                  rg_tra.nro_cta_referencia := to_number(substr(rg_tra.nro_cta_referencia,-7));
               exception
                  when others then
                     rg_tra.nro_cta_referencia := substr(msj.texto,instr(msj.texto,'/')+1);
               end;
            end if;

            --busca el cliente principal de la cuenta
            begin
               rg_tra.cod_per_beneficiario  := fug_obt_cli_principal(rg_tra.nro_cta_referencia);
            exception
               when others then
                  rg_tra.cod_per_beneficiario := null;
            end;

            --si pudo recuperar el cliente principal busco el nro de documento
            if rg_tra.cod_per_beneficiario is not null then
               begin
                  select nro_documento
                  into rg_tra.nro_doc_beneficiario
                  from ba_personas
                  where cod_persona = rg_tra.cod_per_beneficiario;
               exception
               when others then
                  rg_tra.nro_doc_beneficiario := null;
               end;

               --recupero pais, ciudad, nombre ciudad
               begin
                  select a.cod_pais, a.cod_ciudad, b.descripcion
                  into rg_tra.cod_pai_beneficiario, rg_tra.cod_ciu_beneficiario, rg_tra.nom_ciu_beneficiario
                  from ba_direcciones a, ba_ciudades b
                  where a.cod_persona = rg_tra.cod_per_beneficiario
                  and a.cod_pais = b.cod_pais
                  and a.cod_ciudad = b.cod_ciudad
                  and a.principal = 'S';
               exception
               when others then
                  rg_tra.cod_pai_beneficiario := v_cod_pai_entidad;
                  rg_tra.cod_ciu_beneficiario := null;
                  rg_tra.nom_ciu_beneficiario := null;
               end;

               -- recupero telefono del cliente si no vino en el mensaje o no se pudo cargar
               if rg_tra.tel_beneficiario is null then
                  begin
                     select area||telefono
                     into rg_tra.tel_beneficiario
                     from ba_telefonos
                     where cod_persona = rg_tra.cod_per_beneficiario
                     and principal = 'S';
                  exception
                  when others then
                     rg_tra.tel_beneficiario := null;
                  end;
               end if;
            end if;
         elsif instr(upper(msj.texto),upper('/ident.')) >0 then -- NRO DOCUMENTO
            rg_tra.nro_doc_beneficiario := substr(msj.texto,instr(msj.texto,'/')+7);
            --busco la persona con el numero de documento
            begin
               select cod_persona
                 into rg_tra.cod_per_beneficiario
                 from ba_personas
                where cod_tip_documento = 1
                  and nro_documento = rg_tra.nro_doc_beneficiario;
            exception
               when others then
                  rg_tra.cod_per_beneficiario := null;
            end;
         end if;

         fetch mensaje into msj;
         rg_tra.nom_beneficiario := msj.texto;
         rg_tra.msj_swift := rg_tra.msj_swift || chr(10) || msj.texto;
         fetch mensaje into msj;
         rg_tra.dir_beneficiario := msj.texto;
         rg_tra.msj_swift := rg_tra.msj_swift || chr(10) || msj.texto;
         fetch mensaje into msj;
         rg_tra.msj_swift := rg_tra.msj_swift || chr(10) || msj.texto;
         if substr(msj.texto,1,1) between 'A' and 'Z' then -- solo si hay ciudad
           rg_tra.nom_ciu_beneficiario := msj.texto;
           if instr(rg_tra.nom_ciu_beneficiario,'PARAGUAY') > 3 then
               -- viene el pais con la ciudad
               rg_tra.cod_pai_beneficiario := v_cod_pai_entidad;
               rg_tra.nom_ciu_beneficiario := trim(replace(rg_tra.nom_ciu_beneficiario,'PARAGUAY',''));
           end if;
           fetch mensaje into msj;
           rg_tra.msj_swift := rg_tra.msj_swift || chr(10) || msj.texto;
           if substr(msj.texto,1,1) between 'A' AND 'Z' then
              -- tiene pais, ver si es españa
              if msj.texto in ('PARAGUAY') then
                 rg_tra.cod_pai_beneficiario := v_cod_pai_entidad;
              end if;
           else
              rg_tra.cod_pai_beneficiario := v_cod_pai_entidad;
           end if;

           -- busco el codigo de la ciudad del beneficiario si existe
           begin
              select cod_ciudad
                into rg_tra.cod_ciu_beneficiario
                from ba_ciudades
               where cod_pais = rg_tra.cod_pai_beneficiario
                 and descripcion = rg_tra.nom_ciu_beneficiario;
           exception
              when others then
                  rg_tra.cod_ciu_beneficiario := null;
           end;
         else
           rg_tra.cod_pai_beneficiario := v_cod_pai_entidad;
         end if;

         if rg_tra.cod_per_beneficiario is not null then
            -- recupero telefono del cliente si no vino en el mensaje o no se pudo cargar
            if rg_tra.tel_beneficiario is null then
               begin
                  select area||telefono
                  into rg_tra.tel_beneficiario
                  from ba_telefonos
                  where cod_persona = rg_tra.cod_per_beneficiario
                  and principal = 'S';
               exception
               when others then
                  rg_tra.tel_beneficiario := null;
               end;
            end if;

            if rg_tra.cod_ciu_beneficiario is null then
               --recupero ciudad, nombre ciudad
               begin
                  select a.cod_ciudad, b.descripcion
                  into rg_tra.cod_ciu_beneficiario, rg_tra.nom_ciu_beneficiario
                  from ba_direcciones a, ba_ciudades b
                  where a.cod_persona = rg_tra.cod_per_beneficiario
                  and a.cod_pais = b.cod_pais
                  and a.cod_ciudad = b.cod_ciudad
                  and a.principal = 'S';
               exception
               when others then
                  rg_tra.cod_ciu_beneficiario := null;
                  rg_tra.nom_ciu_beneficiario := null;
               end;
            end if;
         end if;
      end if;

      if substr(msj.texto,1,4) = ':70:' then -- comentario
         rg_tra.observacion  := substr(msj.texto,5);
      elsif substr(msj.texto,1,5) = ':71A:' then -- tipo de cargo
         rg_tra.tip_cargo := substr(msj.texto,6);
      elsif substr(msj.texto,1,4) = ':72:' then --tambien es comentario
         rg_tra.observacion  := rg_tra.observacion||' '||substr(msj.texto,5);
      end if;
  end loop;
  --P_CAN_REG_PROCESADO := v_can_reg_ins_lote;
  return to_char(v_can_reg_procesado,'000000');
  -- ya no se graba el ultimo porque se supone que todos los mensajes tienen pie -}, es decir que el ultimo
  -- ya se cargo dentro del ciclo.
END;
/

