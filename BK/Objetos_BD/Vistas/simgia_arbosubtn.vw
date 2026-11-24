create or replace force view it.simgia_arbosubtn as
select atit.serie TNSERIE, (select min(accer.nro_certificado) from ah_cta_certificados accer
                            where atit.nro_titulo = accer.nro_titulo and atit.serie = accer.ser_titulo) TNDESDE,
       (select max(accer.nro_certificado) from ah_cta_certificados accer
       where atit.nro_titulo = accer.nro_titulo and atit.serie = accer.ser_titulo) TNHASTA,
       '0' TNSEQ, atit.nro_titulo TNTITUR, atit.cod_persona TNNUMCLIEN, bper.tipo TNTIPOPER,
       atit.beneficiario TNNOMSIGLA,
       btdoc.abreviatura TNTIPODOC, bper.nro_documento TNNRODOC,
        (select fug_obt_paradicional(accer.nro_cuenta, 'PER_CONTACTO') from ah_cta_certificados accer
        where atit.nro_titulo = accer.nro_titulo and atit.serie = accer.ser_titulo and rownum = 1) TNCONTACTO,

         beqpa.cod_pais_bbva TNNACION,

       ' ' TNFENACIMI, ' ' TNESTADOCI,
        (select fug_obt_paradicional(accer.nro_cuenta, 'DAT_CONYUGE') from ah_cta_certificados accer
        where atit.nro_titulo = accer.nro_titulo and atit.serie = accer.ser_titulo and rownum = 1) TNCONYUGE,

       ' ' TNDOMIC,
      ' ' TNCIUDAD, 0 TNPAISRES, ' ' TNTELEF1, ' ' TNTELEF2, ' ' TNFAX,

       ' ' TNEMAIL,
       nvl((select substr(fug_obt_paradicional(accer.nro_cuenta, 'NRO_CTA_ADICIONAL'),1,2) from ah_cta_certificados accer
        where atit.nro_titulo = accer.nro_titulo and atit.serie = accer.ser_titulo and rownum = 1),0)  TNSUC,

         nvl(PAI_INT.FU_SIM_OBT_TIP_CUENTA((select substr(fug_obt_paradicional(accer.nro_cuenta, 'NRO_CTA_ADICIONAL'),3,2)
         from ah_cta_certificados accer where atit.nro_titulo = accer.nro_titulo and atit.serie = accer.ser_titulo and rownum = 1),
        (select accer.cod_moneda from ah_cta_certificados accer
        where atit.nro_titulo = accer.nro_titulo and atit.serie = accer.ser_titulo and rownum = 1)),0) TNCTA,


        nvl((select substr(fug_obt_paradicional(accer.nro_cuenta, 'NRO_CTA_ADICIONAL'),5,6) from ah_cta_certificados accer
        where atit.nro_titulo = accer.nro_titulo and atit.serie = accer.ser_titulo and rownum = 1),0) TNSUB,


       to_char(atit.fec_apertura, 'yyyymmdd') TNFEREG, atit.usu_insercion TNUSUARIO

from  ah_titulos atit, ba_personas bper, ba_tip_documentos btdoc,it.equiv_paises beqpa

where atit.cod_persona = bper.cod_persona
and   bper.cod_tip_documento = btdoc.cod_tip_documento
and   beqpa.cod_pais_it = bper.cod_pais


/*
union

select atit.serie TNSERIE, (select min(accer.nro_certificado) from ah_cta_certificados accer
                            where atit.nro_titulo = accer.nro_titulo and atit.serie = accer.ser_titulo) TNDESDE,
       (select max(accer.nro_certificado) from ah_cta_certificados accer
       where atit.nro_titulo = accer.nro_titulo and atit.serie = accer.ser_titulo) TNHASTA,
       '0' TNSEQ, atit.nro_titulo TNTITUR, atit.cod_persona TNNUMCLIEN, bper.tipo TNTIPOPER,
       atit.beneficiario TNNOMSIGLA,
       btdoc.abreviatura TNTIPODOC, bper.nro_documento TNNRODOC, (select bpervi.nom_completo from
       ba_personas bpervi, ba_vinculos where bpervi.cod_persona = ba_vinculos.cod_per_vinculo
       and ba_vinculos.cod_persona = bper.cod_persona and ba_vinculos.tipo = 'CA') TNCONTACTO, beqpa.cod_pais_bbva TNNACION,
       to_char(bperj.fec_apertura, 'yyyymmdd') TNFENACIMI, ' ' TNESTADOCI, ' ' TNCONYUGE,
       bdir.direccion TNDOMIC,
       bciu.descripcion TNCIUDAD, ' ' TNPAISRES, (select concat(btel.area, btel.telefono) from  ba_telefonos btel
       where btel.cod_persona = bper.cod_persona and btel.principal = 'S') TNTELEF1,
       ' ' TNTELEF2, ' ' TNFAX,
       bper.dir_correo TNEMAIL, gccli.cod_oficina TNSUC, PAI_INT.FU_SIM_OBT_TIP_CUENTA(gcuen.cod_modulo, gcuen.cod_modalidad, gcuen.cod_moneda) TNCTA ,SUBSTR(gccli.nro_cuenta, 5, 6) TNSUB,
       to_char(atit.fec_apertura, 'yyyymmdd') TNFEREG, atit.usu_insercion TNUSUARIO

from  ge_cta_clientes gccli, ah_titulos atit, ba_personas bper, ba_tip_documentos btdoc,
      ba_per_juridicas bperj, ba_ciudades bciu, ge_cuentas gcuen,
      ba_direcciones bdir, it.equiv_paises beqpa

where atit.cod_persona = bper.cod_persona
and   bper.cod_tip_documento = btdoc.cod_tip_documento
and   gcuen.nro_cuenta = gccli.nro_cuenta
and   gccli.cod_persona = atit.cod_persona
and   bper.cod_persona = bperj.cod_persona
and   bdir.cod_persona = bper.cod_persona
and   beqpa.cod_pais_it = bper.cod_pais
and   bciu.cod_ciudad = bdir.cod_ciudad
and   bciu.cod_pais = bdir.cod_pais
and   bdir.principal = 'S';*/;

