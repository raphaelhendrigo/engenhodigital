"""Home screen for Engenho Digital app."""

from kivy.properties import ListProperty, StringProperty
from kivy.uix.screenmanager import Screen


class HomeScreen(Screen):
    """Landing screen presenting Engenho Digital."""

    intro_title = StringProperty("Engenho Digital")
    intro_subtitle = StringProperty("Projetos & Sistemas")
    intro_description = StringProperty(
        "Tecnologia, inovação e produtos digitais feitos sob medida "
        "para impulsionar negócios."
    )

    hero_title = StringProperty("Engenharia de software & projetos elétricos")
    hero_subtitle = StringProperty("Soluções digitais e elétricas")
    hero_tagline = StringProperty("para tirar seus projetos do papel.")
    hero_body = StringProperty(
        "A Engenho Digital integra desenvolvimento de softwares sob medida, "
        "projetos elétricos em CAD/CAM e automação de processos. "
        "Combinamos engenharia, dados e experiência em campo para entregar "
        "soluções enxutas, modernas e prontas para produção."
    )

    cta_primary = StringProperty("Agendar conversa técnica")
    cta_secondary = StringProperty("Ver projetos em destaque \u2192")

    stats = ListProperty(
        [
            {"value": "+10", "label": "Anos com tecnologia"},
            {"value": "Full-stack", "label": "Web · APIs · Data"},
            {"value": "CAD/CAM", "label": "Projetos elétricos detalhados"},
        ]
    )

    pillars = ListProperty(
        [
            {
                "title": "Software sob medida para o seu negócio",
                "description": "Sistemas web em Flask, React e cloud, focados em automação, dashboards e integrações.",
            },
            {
                "title": "Projetos elétricos em CAD/CAM",
                "description": "Plantas, diagramas, quadros e detalhamento técnico para obras, indústrias e escritórios de engenharia.",
            },
            {
                "title": "Consultoria em dados e automação",
                "description": "Uso inteligente de dados para reduzir retrabalho, padronizar processos e ganhar previsibilidade.",
            },
        ]
    )

    profiles = ListProperty(
        [
            {
                "name": "Raphael Hendrigo de Souza Gonçalves",
                "role": "Engenharia & Dados",
                "bullets": [
                    "Liderança técnica em soluções web, automação e analytics.",
                    "Pós-graduando no MBA de Ciência de Dados do USP ICMC em São Carlos (SP).",
                    "Especialista em transformar dados operacionais em insights acionáveis.",
                ],
            },
            {
                "name": "Edgar de Almeida",
                "role": "Projetos Elétricos & CAD/CAM",
                "bullets": [
                    "Domínio de plataformas CAD, modelagem 2D/3D e detalhamento executivo.",
                    "Experiência em coordenação de listas de materiais, diagramas e quadros de cargas.",
                    "Referência para garantir conformidade técnica e eficiência energética.",
                ],
            },
        ]
    )

    highlight_projects = ListProperty(
        [
            {
                "category": "Software · Gestão",
                "title": "Portal de Automação de Processos Internos",
                "summary": "Sistema web em Python/Flask integrado à nuvem para controle de demandas, geração automática de documentos e painéis gerenciais.",
                "bullets": [
                    "Redução de retrabalho operacional.",
                    "Histórico completo e rastreabilidade.",
                    "Exportação de relatórios em poucos cliques.",
                ],
            },
            {
                "category": "Elétrica · CAD/CAM",
                "title": "Projeto Elétrico de Escritório Corporativo",
                "summary": "Elaboração completa de plantas, diagramas e quadros de cargas para implantação de novo escritório, com foco em segurança e eficiência energética.",
                "bullets": [
                    "Layout em CAD com revisões controladas.",
                    "Documentação pronta para aprovação.",
                    "Lista de materiais organizada por ambiente.",
                ],
            },
            {
                "category": "Dados · Automação",
                "title": "Monitoramento de Indicadores Técnicos",
                "summary": "Construção de pipeline de dados para concentrar informações em um único painel, permitindo decisões mais rápidas e baseadas em evidências.",
                "bullets": [
                    "Integração de múltiplas fontes de dados.",
                    "Atualização automática de métricas.",
                    "Visualização clara para times técnicos e gestores.",
                ],
            },
        ]
    )
